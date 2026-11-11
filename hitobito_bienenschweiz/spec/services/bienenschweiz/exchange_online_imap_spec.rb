# frozen_string_literal: true

# Copyright (c) 2026, BienenSchweiz. This file is licensed under the
# Affero General Public License version 3 or later.

require "spec_helper"

describe "Exchange Online IMAP" do
  let(:token_client) { Bienenschweiz::ExchangeOnlineToken }
  let(:mailbox) { "lists@example.com" }
  let(:imap) { instance_double(Net::IMAP, disconnected?: false, disconnect: nil) }
  let(:retriever) do
    Config::Options.new(type: "imap", interval: 1, config: Config::Options.new(
      address: "outlook.office365.com", user_name: mailbox, port: 993
    ))
  end

  before do
    stub_const("MailConfig", Class.new(MailConfig))
    stub_const("Bienenschweiz::ExchangeOnlineToken", Class.new(token_client))
    allow(Settings.email).to receive(:retriever).and_return(retriever)
    allow(ENV).to receive(:key?).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    {
      "BIENENSCHWEIZ_IMAP_TENANT_ID" => "example.onmicrosoft.com",
      "BIENENSCHWEIZ_IMAP_CLIENT_ID" => "test-client",
      "BIENENSCHWEIZ_IMAP_CLIENT_SECRET" => "test-secret"
    }.each do |name, value|
      allow(ENV).to receive(:key?).with(name).and_return(true)
      allow(ENV).to receive(:[]).with(name).and_return(value)
    end
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

  it "keeps the legacy retriever when OAuth is disabled and there is no mail.yml" do
    allow(token_client).to receive(:configured?).and_return(false)
    allow(MailConfig).to receive(:load_file).and_return(nil)

    expect(JobManager.new.send(:mail_jobs)).to eq(MailRelayJob)
  end
end
