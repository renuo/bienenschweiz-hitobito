# frozen_string_literal: true

# Copyright (c) 2026, BienenSchweiz. This file is licensed under the
# Affero General Public License version 3 or later.

require "spec_helper"

describe Bienenschweiz::ExchangeOnlineToken do
  subject(:client) { Class.new(described_class) }

  let(:tenant) { "example.onmicrosoft.com" }
  let(:client_secret) { "test-secret" }
  let(:endpoint) { "https://login.microsoftonline.com/#{tenant}/oauth2/v2.0/token" }
  let(:error_class) { Bienenschweiz::ExchangeOnlineToken::Error }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("BIENENSCHWEIZ_IMAP_TENANT_ID").and_return(tenant)
    allow(ENV).to receive(:[]).with("BIENENSCHWEIZ_IMAP_CLIENT_ID").and_return("test-client")
    allow(ENV).to receive(:[]).with("BIENENSCHWEIZ_IMAP_CLIENT_SECRET").and_return(client_secret)
  end

  it "can retry a malformed response and caches the recovered token" do
    request = stub_request(:post, endpoint).to_return(
      {body: "invalid JSON"},
      {body: {access_token: "recovered", expires_in: "3600"}.to_json}
    )

    expect { client.access_token }
      .to raise_error(error_class, "Invalid Exchange Online token response")
    expect(client.access_token).to eq("recovered")
    expect(client.access_token).to eq("recovered")
    expect(request).to have_been_requested.twice
  end

  [[], {expires_in: 3600}, {access_token: "", expires_in: 3600},
    {access_token: "test-token", expires_in: 0}].each do |payload|
    it "rejects an unusable token response #{payload.inspect}" do
      stub_request(:post, endpoint).to_return(body: payload.to_json)

      expect { client.access_token }
        .to raise_error(error_class, "Invalid Exchange Online token response")
    end
  end

  it "reports the HTTP status for a rejected token request" do
    stub_request(:post, endpoint).to_return(status: 401, body: '{"error":"invalid_client"}')

    expect { client.access_token }
      .to raise_error(error_class, "Exchange Online token request failed (HTTP 401)")
  end

  it "reports a network timeout" do
    stub_request(:post, endpoint).to_timeout

    expect { client.access_token }
      .to raise_error(error_class, "Could not reach the Exchange Online token endpoint")
  end

  context "with a missing client secret" do
    let(:client_secret) { nil }

    it "reports the missing credential before making a request" do
      expect { client.access_token }
        .to raise_error(error_class, /Missing BIENENSCHWEIZ_IMAP_CLIENT_SECRET/)
    end
  end

  context "with an invalid tenant ID" do
    let(:tenant) { "invalid/tenant" }

    it "rejects the tenant ID before making a request" do
      expect { client.access_token }
        .to raise_error(error_class, "Invalid BIENENSCHWEIZ_IMAP_TENANT_ID")
    end
  end
end
