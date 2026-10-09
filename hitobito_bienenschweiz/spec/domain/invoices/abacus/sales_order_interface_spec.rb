# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::SalesOrderInterface do
  let(:host) { "https://abacus.example.com" }
  let(:api) { "#{host}/api/entity/v1/mandants/1234" }
  let(:person) { Fabricate(:magazine_subscriber, abacus_subject_key: 7) }
  let(:subscription) do
    Fabricate(:magazine_subscription, person:, start_date: Date.new(2025, 12, 1))
  end
  let(:invoice) do
    ExternalInvoice::Magazine.create!(person:, link: subscription, total: 85,
      period_start: Date.new(2026, 12, 1), issued_at: Date.new(2026, 12, 1),
      sent_at: Date.new(2026, 10, 7))
  end
  let(:positions) do
    [Invoices::Abacus::InvoicePosition.new(name: "Abo 01.12.2026 - 30.11.2027",
      article_number: "4711", amount: 42.5, count: 2)]
  end
  let(:sales_order) { Invoices::Abacus::SalesOrder.new(invoice, positions) }
  let(:interface) { described_class.new }

  before do
    allow(Invoices::Abacus::Config).to receive_messages(host:, mandant: 1234,
      username: "user", password: "secret")
    stub_request(:get, "#{host}/.well-known/openid-configuration")
      .to_return(status: 200, body: {token_endpoint: "#{host}/oauth/token"}.to_json)
    stub_request(:post, "#{host}/oauth/token")
      .with(headers: {"Authorization" => "Basic #{Base64.strict_encode64("user:secret")}"})
      .to_return(status: 200, body: {access_token: "token", expires_in: 600}.to_json)
  end

  describe "#create_batch" do
    let(:response_boundary) { "batch-boundary-response" }

    before do
      stub_request(:post, "#{api}/$batch")
        .with(headers: {"Authorization" => "Bearer token"})
        .to_return(
          status: 202,
          headers: {"Content-Type" => "multipart/mixed;boundary=#{response_boundary}"},
          body: <<~HTTP
            --#{response_boundary}\r
            Content-Type: application/http\r
            Content-Transfer-Encoding: binary\r
            \r
            HTTP/1.1 201 Created\r
            Content-Type: application/json\r
            \r
            {"SalesOrderId":42,"SalesOrderBacklogId":0}\r
            --#{response_boundary}--\r
          HTTP
        )
    end

    it "creates the sales orders and assigns the abacus key" do
      parts = interface.create_batch([sales_order])

      expect(parts.map(&:success?)).to eq([true])
      expect(invoice.reload.abacus_sales_order_key).to eq(42)
      expect(invoice).to be_open
    end

    it "sends the sales order with its positions" do
      interface.create_batch([sales_order])

      expect(WebMock).to(have_requested(:post, "#{api}/$batch").with do |request|
        expect(request.body).to include("POST SalesOrders HTTP/1.1")
        json = JSON.parse(request.body[/^\{.*\}\r$/])
        expect(json).to include(
          "CustomerId" => 7,
          "InvoiceDate" => "2026-10-07",
          "InvoiceValueDate" => "2026-12-01",
          "TotalAmount" => 85.0,
          "Language" => "de",
          "DocumentCodeInvoice" => "RA",
          "ProcessFlowNumber" => 4,
          "UserFields" => {"UserField1" => invoice.id.to_s, "UserField2" => "hitobito",
                           "UserField3" => "Letter"}
        )
        expect(json["Positions"]).to eq([{
          "PositionNumber" => 1,
          "Type" => "Product",
          "Pricing" => {"PriceAfterFinding" => 42.5},
          "Quantity" => {"Ordered" => 2, "Charged" => 2, "Delivered" => 2},
          "Product" => {"Description" => "Abo 01.12.2026 - 30.11.2027", "ProductNumber" => "4711"}
        }])
      end)
    end
  end

  describe "#cancel" do
    it "flags the sales order as cancelled in abacus" do
      invoice.update!(abacus_sales_order_key: 42, state: :open)
      request = stub_request(:patch, "#{api}/SalesOrders(SalesOrderId=42,SalesOrderBacklogId=0)")
        .with(body: {UserFields: {UserField21: true}}.to_json)
        .to_return(status: 200, body: "{}")

      interface.cancel(sales_order)

      expect(request).to have_been_requested
      expect(invoice.reload).to be_cancelled
    end
  end
end
