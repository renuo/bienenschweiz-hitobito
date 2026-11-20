# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::BatchResponse do
  let(:boundary) { "batch-boundary-response" }
  let(:request_parts) do
    [
      Invoices::Abacus::BatchRequestPart.new(:post, "SalesOrders", {customer_id: 1}, :first),
      Invoices::Abacus::BatchRequestPart.new(:post, "SalesOrders", {customer_id: 2}, :second)
    ]
  end

  def http_part(status, body)
    <<~HTTP
      Content-Type: application/http\r
      Content-Transfer-Encoding: binary\r
      \r
      HTTP/1.1 #{status}\r
      Content-Type: application/json\r
      \r
      #{body}\r
    HTTP
  end

  def response(*parts)
    body = parts.map { |part| "--#{boundary}\r\n#{part}" }.join + "--#{boundary}--\r\n"
    instance_double(RestClient::Response, body:,
      headers: {content_type: "multipart/mixed; boundary=#{boundary}"})
  end

  describe "#parts" do
    it "parses the parts with their requests" do
      parts = described_class.new(response(
        http_part("201 Created", '{"SalesOrderId":42}'),
        http_part("400 Bad Request", '{"error":{"message":"Invalid customer"}}')
      ), request_parts).parts

      expect(parts.map(&:status)).to eq([201, 400])
      expect(parts.map(&:context_object)).to eq([:first, :second])
      expect(parts.first).to be_created
      expect(parts.first.json).to eq(sales_order_id: 42)
      expect(parts.first.error).to be_nil
      expect(parts.first.error_payload).to be_nil
      expect(parts.second).not_to be_success
      expect(parts.second.error).to eq("Invalid customer")
      expect(parts.second.error_payload).to eq(
        request: {method: :post, path: "SalesOrders", params: {customer_id: 2}},
        status: 400,
        message: "Invalid customer"
      )
    end

    it "includes the response body in the error payload if it has no error message" do
      parts = described_class.new(response(
        http_part("201 Created", "{}"),
        http_part("500 Internal Server Error", "Server down")
      ), request_parts).parts

      expect(parts.second.error).to be_nil
      expect(parts.second.error_payload)
        .to include(status: 500, response_body: "Server down\r\n")
    end

    it "fails if the number of parts does not match the requests" do
      batch = described_class.new(response(http_part("201 Created", "{}")), request_parts)

      expect { batch.parts }.to raise_error(RestClient::Exception,
        "Batch response does not contain expected number of parts")
    end

    it "fails without multipart boundary" do
      batch = described_class.new(
        instance_double(RestClient::Response, body: "{}",
          headers: {content_type: "application/json"}),
        request_parts
      )

      expect { batch.parts }.to raise_error(RestClient::Exception,
        "Could not parse multipart boundary from content type header")
    end
  end
end
