# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::SalesOrder do
  let(:person) { Fabricate(:magazine_subscriber, abacus_subject_key: 7) }
  let(:subscription) do
    Fabricate(:magazine_subscription, person:, start_date: Date.new(2025, 12, 1))
  end
  let(:created_at) { Time.zone.local(2026, 10, 7, 2, 33) }
  let(:sent_at) { Date.new(2026, 10, 7) }
  let(:issued_at) { Date.new(2026, 12, 1) }
  let(:invoice) do
    travel_to(created_at) do
      ExternalInvoice::Magazine.create!(person:, link: subscription, total: 85,
        period_start: issued_at, issued_at:, sent_at:)
    end
  end

  subject(:attrs) { described_class.new(invoice).sales_order_attrs }

  context "with dates before 2027" do
    it "moves all dates to 2027-01-01" do
      expect(attrs).to include(
        order_date: Date.new(2027, 1, 1),
        delivery_date: Date.new(2027, 1, 1),
        invoice_date: Date.new(2027, 1, 1),
        invoice_value_date: Date.new(2027, 1, 1)
      )
    end

    it "keeps the real dates in the comment" do
      expect(attrs[:comment]).to eq("Effektiv: Rechnung 07.10.2026, Valuta 01.12.2026")
      expect(attrs[:comment].length).to be <= described_class::COMMENT_MAX_LENGTH
    end
  end

  context "with only some dates before 2027" do
    let(:created_at) { Time.zone.local(2026, 12, 20, 2, 33) }
    let(:sent_at) { Date.new(2026, 12, 20) }
    let(:issued_at) { Date.new(2027, 2, 1) }

    it "moves only the earlier dates" do
      expect(attrs).to include(
        order_date: Date.new(2027, 1, 1),
        delivery_date: Date.new(2027, 1, 1),
        invoice_date: Date.new(2027, 1, 1),
        invoice_value_date: Date.new(2027, 2, 1),
        comment: "Effektiv: Rechnung 20.12.2026, Valuta 01.02.2027"
      )
    end
  end

  context "with dates from 2027 on" do
    let(:created_at) { Time.zone.local(2027, 1, 1, 2, 33) }
    let(:sent_at) { Date.new(2027, 1, 1) }
    let(:issued_at) { Date.new(2027, 3, 1) }

    it "uses the real dates without comment" do
      expect(attrs).to include(
        order_date: Date.new(2027, 1, 1),
        delivery_date: Date.new(2027, 1, 1),
        invoice_date: Date.new(2027, 1, 1),
        invoice_value_date: Date.new(2027, 3, 1)
      )
      expect(attrs).not_to have_key(:comment)
    end
  end

  describe "#abacus_key" do
    it "is nil without sales order key" do
      expect(described_class.new(invoice).abacus_key).to be_nil
    end

    it "contains the sales order key and backlog id" do
      invoice.update!(abacus_sales_order_key: 42)

      expect(described_class.new(invoice).abacus_key)
        .to eq(sales_order_id: 42, sales_order_backlog_id: 0)
    end
  end

  describe "payment" do
    it "is not sent without configured payment_slip_internal_number" do
      allow(Invoices::Abacus::Config).to receive(:payment_slip_internal_number).and_return(nil)
      expect(attrs).not_to have_key(:payment)
    end

    it "sends the configured payment_slip_internal_number, also 0" do
      allow(Invoices::Abacus::Config).to receive(:payment_slip_internal_number).and_return(0)
      expect(attrs[:payment]).to eq(payment_slip_internal_number: 0)
    end
  end
end
