# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe "Exchange Online IMAP" do
  let(:token_client) { Bienenschweiz::ExchangeOnlineToken }
  let(:mailbox) { "lists@example.com" }
  let(:imap) { instance_double(Net::IMAP, disconnected?: false, disconnect: nil) }
  let(:configuration) do
    {tenant_id: "example.onmicrosoft.com", client_id: "test-client", client_secret: "test-secret"}
  end
  let(:retriever) do
    Config::Options.new(type: "imap", interval: 1, config: Config::Options.new(
      address: "outlook.office365.com", user_name: mailbox, port: 993
    ))
  end

  before do
    stub_const("MailConfig", Class.new(MailConfig))
    stub_const("Bienenschweiz::ExchangeOnlineToken", Class.new(token_client))
    allow(Settings.email).to receive(:retriever).and_return(retriever)
    allow(Rails.configuration.x).to receive(:exchange_online_imap).and_return(configuration)
  end

  it "selects the bulk mail retriever and renews tokens used by its IMAP connector" do
    now = 0
    allow(token_client).to receive(:monotonic_time) { now }
    request = stub_request(:post, "https://login.microsoftonline.com/example.onmicrosoft.com/oauth2/v2.0/token")
      .with(body: {
        "grant_type" => "client_credentials", "scope" => "https://outlook.office365.com/.default",
        "client_id" => "test-client", "client_secret" => "test-secret"
      }).to_return(
        {body: {access_token: "first", expires_in: 3600}.to_json},
        {body: {access_token: "second", expires_in: 3600}.to_json}
      )
    allow(Net::IMAP).to receive(:new).with("outlook.office365.com", port: 993, ssl: true)
      .and_return(imap)
    allow(imap).to receive(:select).with("INBOX")
    allow(imap).to receive(:uid_search).with(["ALL"]).and_return([42])
    allow(imap).to receive(:authenticate)

    expect(JobManager.new.send(:mail_jobs)).to eq(MailingLists::MailRetrieverJob)
    connector = Imap::Connector.new
    expect(connector.fetch_mail_uids(:inbox)).to eq([42])
    now = 3000
    connector.fetch_mail_uids(:inbox)
    now = 3541
    connector.fetch_mail_uids(:inbox)

    expect(imap).to have_received(:authenticate).with("XOAUTH2", mailbox, "first").twice
    expect(imap).to have_received(:authenticate).with("XOAUTH2", mailbox, "second").once
    expect(request).to have_been_requested.twice
  end

  it "disconnects the socket if Exchange rejects authentication" do
    allow(token_client).to receive(:access_token).and_return("token")
    allow(Net::IMAP).to receive(:new).and_return(imap)
    allow(imap).to receive(:authenticate).and_raise(Net::IMAP::Error, "AUTHENTICATE failed")

    expect { Imap::Connector.new.fetch_mail_uids(:inbox) }
      .to raise_error(Net::IMAP::Error, "AUTHENTICATE failed")
    expect(imap).to have_received(:disconnect)
  end

  it "reuses an already authenticated connection for the next IMAP operation" do
    allow(token_client).to receive(:access_token).and_return("token")
    allow(Net::IMAP).to receive(:new).with("outlook.office365.com", port: 993, ssl: true)
      .and_return(imap)
    allow(imap).to receive(:authenticate)
    allow(imap).to receive(:select).with("INBOX")
    allow(imap).to receive(:uid_search).with(["ALL"]).and_return([42])

    connector = Imap::Connector.new
    connector.send(:connect)
    expect(connector.fetch_mail_uids(:inbox)).to eq([42])
    expect(imap).to have_received(:authenticate).with("XOAUTH2", mailbox, "token").once
    expect(imap).to have_received(:disconnect).once
  end

  it "surfaces token failures before opening an IMAP connection" do
    allow(token_client).to receive(:access_token).and_raise(token_client::Error,
      "Token unavailable")
    expect(Net::IMAP).not_to receive(:new)

    expect { Imap::Connector.new.fetch_mail_uids(:inbox) }
      .to raise_error(token_client::Error, "Token unavailable")
  end

  it "reports incomplete IMAP settings" do
    retriever.config = nil

    expect { MailConfig.retriever_imap }
      .to raise_error(token_client::Error, /address and user_name/)
  end

  it "keeps the legacy retriever when OAuth is disabled and there is no mail.yml" do
    configuration.transform_values! { nil }
    allow(MailConfig).to receive(:load_file).and_return(nil)

    expect(JobManager.new.send(:mail_jobs)).to eq(MailRelayJob)

    expect(Net::IMAP).to receive(:new).with("outlook.office365.com", port: 993, ssl: true)
      .and_return(imap)
    expect(imap).to receive(:login).with(mailbox, nil)
    allow(imap).to receive(:select).with("INBOX")
    allow(imap).to receive(:uid_search).with(["ALL"]).and_return([42])
    expect(imap).to receive(:close)
    expect(imap).to receive(:disconnect)

    expect(Imap::Connector.new.fetch_mail_uids(:inbox)).to eq([42])
  end

  it "rejects incomplete OAuth configuration instead of falling back to legacy authentication" do
    configuration[:client_secret] = nil

    expect(token_client).to be_configured
    expect { token_client.access_token }
      .to raise_error(token_client::Error, "Missing client_secret for Exchange Online IMAP")
  end
end
