# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::Client do
  let(:host) { "https://abacus.example.com" }
  let(:api) { "#{host}/api/entity/v1/mandants/1234" }
  let(:client) { described_class.new }

  before do
    allow(Invoices::Abacus::Config).to receive_messages(host:, mandant: 1234,
      username: "user", password: "secret")
    stub_request(:get, "#{host}/.well-known/openid-configuration")
      .to_return(status: 200, body: {token_endpoint: "#{host}/oauth/token"}.to_json)
    stub_request(:post, "#{host}/oauth/token")
      .to_return(status: 200, body: {access_token: "token", expires_in: 600}.to_json)
  end

  describe "#list" do
    it "encodes spaces in query params as %20" do
      request = stub_request(:get,
        "#{api}/SalesOrders?%24filter=Name%20eq%20%27A%2BB%27&%24orderby=Id%20desc")
        .to_return(status: 200, body: {value: [{Id: 1}]}.to_json)

      result = client.list(:sales_order, "$filter" => "Name eq 'A+B'", "$orderby" => "Id desc")

      expect(request).to have_been_requested
      expect(result).to eq([{id: 1}])
    end
  end

  it "cannot be created without configuration" do
    allow(Invoices::Abacus::Config).to receive(:host).and_return(nil)

    expect { described_class.new }.to raise_error("Abacus is not configured")
  end

  describe "#delete" do
    it "deletes the entity" do
      request = stub_request(:delete, "#{api}/Subjects(Id=1)").to_return(status: 204, body: "")

      expect(client.delete(:subject, 1)).to eq({})
      expect(request).to have_been_requested
    end
  end

  describe "bad requests" do
    it "uses the error message of the response" do
      stub_request(:get, "#{api}/Subjects(Id=1)")
        .to_return(status: 400, body: {error: {message: "Invalid subject"}}.to_json)

      expect { client.get(:subject, 1) }
        .to raise_error(RestClient::BadRequest, "Invalid subject")
    end

    it "keeps the original message if the response contains none" do
      stub_request(:get, "#{api}/Subjects(Id=1)").to_return(status: 400, body: "<html/>")

      expect { client.get(:subject, 1) }.to raise_error(RestClient::BadRequest, "400 Bad Request")
    end
  end

  describe "#batch" do
    it "sends nothing if no requests are recorded" do
      expect(client.batch {}).to eq([])
      expect(a_request(:post, "#{api}/$batch")).not_to have_been_made
    end

    it "does not allow nested batches" do
      expect { client.batch { client.batch {} } }
        .to raise_error("Nested batch requests are not allowed")
      expect(client).not_to be_in_batch
    end
  end

  describe "throttling" do
    before do
      stub_request(:get, "#{api}/Subjects(Id=1)").to_return(status: 200, body: {Id: 1}.to_json)
    end

    it "does not wait without max_requests_per_minute" do
      allow(Invoices::Abacus::Config).to receive(:max_requests_per_minute).and_return(nil)
      expect(client).not_to receive(:sleep)

      3.times { client.get(:subject, 1) }
    end

    it "spaces requests evenly according to max_requests_per_minute" do
      allow(Invoices::Abacus::Config).to receive(:max_requests_per_minute).and_return(120)
      allow(client).to receive(:monotonic_now).and_return(100.0)
      sleeps = []
      allow(client).to receive(:sleep) { |seconds| sleeps << seconds }

      2.times { client.get(:subject, 1) }

      # token endpoint, token, then two requests; every one 0.5s after the previous
      expect(sleeps).to eq([0.5, 1.0, 1.5])
    end

    it "does not wait if the last request is long enough ago" do
      allow(Invoices::Abacus::Config).to receive(:max_requests_per_minute).and_return(60)
      times = [0.0, 10.0, 20.0, 30.0]
      allow(client).to receive(:monotonic_now) { times.shift }
      expect(client).not_to receive(:sleep)

      client.get(:subject, 1)
    end

    it "measures the time with the monotonic clock" do
      allow(Invoices::Abacus::Config).to receive(:max_requests_per_minute).and_return(60)
      allow(client).to receive(:sleep)
      expect(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC)
        .at_least(:once).and_call_original

      client.get(:subject, 1)
    end
  end
end

describe Invoices::Abacus::Config do
  describe ".exist?" do
    it "reads host and mandant from the settings" do
      allow(Settings.abacus).to receive_messages(host: "https://abacus.example.com",
        mandant: "1234")

      expect(described_class.host).to eq("https://abacus.example.com")
      expect(described_class.mandant).to eq("1234")
      expect(described_class).to be_exist
    end

    it "is false without mandant" do
      allow(Settings.abacus).to receive_messages(host: "https://abacus.example.com", mandant: nil)

      expect(described_class).not_to be_exist
    end
  end

  describe ".max_requests_per_minute" do
    it "is nil when blank or zero" do
      allow(Settings.abacus).to receive(:max_requests_per_minute).and_return(nil)
      expect(described_class.max_requests_per_minute).to be_nil
      allow(Settings.abacus).to receive(:max_requests_per_minute).and_return(0)
      expect(described_class.max_requests_per_minute).to be_nil
    end

    it "returns the configured integer" do
      allow(Settings.abacus).to receive(:max_requests_per_minute).and_return("200")
      expect(described_class.max_requests_per_minute).to eq(200)
    end
  end

  describe ".payment_slip_internal_number" do
    it "is nil when blank and an integer otherwise, also 0" do
      allow(Settings.abacus).to receive(:payment_slip_internal_number).and_return(nil)
      expect(described_class.payment_slip_internal_number).to be_nil
      allow(Settings.abacus).to receive(:payment_slip_internal_number).and_return(0)
      expect(described_class.payment_slip_internal_number).to eq(0)
      allow(Settings.abacus).to receive(:payment_slip_internal_number).and_return("2")
      expect(described_class.payment_slip_internal_number).to eq(2)
    end
  end
end
