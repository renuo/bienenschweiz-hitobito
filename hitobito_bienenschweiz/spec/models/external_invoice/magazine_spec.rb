# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe ExternalInvoice::Magazine do
  let(:subscription) { Fabricate(:magazine_subscription, start_date: Date.new(2025, 5, 1)) }
  let(:invoice) do
    described_class.create!(person: subscription.person, link: subscription,
      period_start: Date.new(2026, 5, 1), state: :open, abacus_sales_order_key: 42)
  end

  it "is invalid with an unknown state" do
    invoice.state = "unknown"
    expect(invoice).not_to be_valid
  end

  it "allows only one invoice per subscription and period" do
    invoice
    expect do
      described_class.create!(person: subscription.person, link: subscription,
        period_start: invoice.period_start)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  context "when Abacus cancels the invoice" do
    it "terminates the subscription before the invoiced period because it was not paid" do
      invoice.update!(state: :cancelled)

      expect(subscription.reload.end_date).to eq(Date.new(2026, 4, 30))
      expect(subscription.cancellation_reason).to eq("zahl")
    end

    it "keeps a subscription that has already been terminated" do
      subscription.update!(end_date: Date.new(2026, 8, 31), cancellation_reason: "kint")

      invoice.update!(state: :cancelled)

      expect(subscription.reload.end_date).to eq(Date.new(2026, 8, 31))
      expect(subscription.cancellation_reason).to eq("kint")
    end
  end

  it "does not touch the subscription when the invoice is paid" do
    invoice.update!(state: :payed)

    expect(subscription.reload.end_date).to be_nil
  end
end
