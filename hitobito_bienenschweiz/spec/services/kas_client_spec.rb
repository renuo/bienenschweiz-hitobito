# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe KasClient do
  let(:base_url) { "https://kas.example.com" }
  let(:api_token) { "test-token" }
  let(:client) { described_class.new }

  before do
    allow(Settings.kas).to receive(:base_url).and_return(base_url)
    allow(Settings.kas).to receive(:api_token).and_return(api_token)
  end

  describe "#create_fee" do
    let(:fee_params) do
      {
        user_id: 42,
        fee_type_code: "ANNUAL",
        occurred_on: "2026-01-15",
        total_amount: "100.00",
        group_id: 7
      }
    end

    context "when the request succeeds" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees")
          .with(
            body: {fee: fee_params}.to_json,
            headers: {
              "Api-Key" => api_token.to_s,
              "Content-Type" => "application/json",
              "Accept" => "application/json"
            }
          )
          .to_return(status: 201,
            body: {id: 99}.to_json,
            headers: {"Content-Type" => "application/json"})
      end

      it "returns the parsed response body" do
        result = client.create_fee(fee_params)
        expect(result).to eq("id" => 99)
      end
    end

    context "when the API returns a 422 error" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees")
          .to_return(status: 422, body: {error: "invalid params"}.to_json)
      end

      it "raises KasClient::Error with the error message" do
        expect { client.create_fee(fee_params) }.to raise_error(KasClient::Error, /invalid params/)
      end
    end

    context "when the API returns a non-422 server error" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises KasClient::Error with the status and body" do
        expect { client.create_fee(fee_params) }
          .to raise_error(KasClient::Error, /KAS API error 500/)
      end
    end
  end
end
