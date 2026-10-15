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
end
