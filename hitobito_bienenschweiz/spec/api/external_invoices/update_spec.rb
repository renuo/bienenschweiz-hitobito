# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe "external_invoices#update", type: :request do
  let(:service_token) do
    Fabricate(:service_token, layer: groups(:root), permission: :layer_and_below_full,
      invoices: true)
  end
  let(:subscription) { Fabricate(:magazine_subscription, start_date: Date.new(2025, 5, 1)) }
  let(:external_invoice) do
    ExternalInvoice::Magazine.create!(person: subscription.person, link: subscription,
      period_start: Date.new(2026, 5, 1), state: :open, abacus_sales_order_key: 42)
  end
  let(:state) { "payed" }
  let(:payload) do
    {data: {id: external_invoice.id.to_s, type: "external_invoices", attributes: {state:}}}
  end

  def jsonapi_headers
    super.merge("X-TOKEN" => service_token.token)
  end

  subject(:make_request) do
    jsonapi_put "/api/external_invoices/#{external_invoice.id}", payload
  end

  it "updates the state" do
    make_request

    expect(response).to have_http_status(:ok)
    expect(external_invoice.reload).to be_payed
  end

  context "with cancelled state" do
    let(:state) { "cancelled" }

    it "terminates the subscription" do
      make_request

      expect(response).to have_http_status(:ok)
      expect(subscription.reload.end_date).to eq(Date.new(2026, 4, 30))
      expect(subscription.cancellation_reason).to eq("zahl")
    end
  end

  context "with unknown state" do
    let(:state) { "paid" }

    it "rejects the update" do
      make_request

      expect(response).to have_http_status(:unprocessable_content)
      expect(external_invoice.reload).to be_open
    end
  end

  it "is forbidden with read permission" do
    service_token.update!(permission: :layer_and_below_read)
    make_request

    expect(response).to have_http_status(:forbidden)
  end

  it "is forbidden without invoices scope" do
    service_token.update!(invoices: false)
    make_request

    expect(response).to have_http_status(:forbidden)
  end

  it "is forbidden with a token below the root layer" do
    service_token.update!(layer: groups(:aargauer_kantonalverband))
    make_request

    expect(response).to have_http_status(:forbidden)
  end
end
