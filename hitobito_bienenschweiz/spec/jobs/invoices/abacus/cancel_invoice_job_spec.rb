# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::CancelInvoiceJob do
  let(:subscription) { Fabricate(:magazine_subscription, start_date: Date.new(2025, 5, 1)) }
  let(:invoice) do
    ExternalInvoice::Magazine.create!(person: subscription.person, link: subscription,
      period_start: Date.new(2026, 5, 1), state: :cancelled, abacus_sales_order_key: 42)
  end
  let(:interface) { instance_double(Invoices::Abacus::SalesOrderInterface) }

  subject(:job) { described_class.new(invoice) }

  before { allow(Invoices::Abacus::SalesOrderInterface).to receive(:new).and_return(interface) }

  describe "#perform" do
    it "cancels the sales order in Abacus" do
      expect(interface).to receive(:cancel) do |sales_order|
        expect(sales_order.entity).to eq(invoice)
      end

      job.perform
    end

    it "does nothing if the invoice has not been sent to Abacus" do
      invoice.update!(abacus_sales_order_key: nil)
      expect(interface).not_to receive(:cancel)

      job.perform
    end

    it "does nothing if the invoice has been deleted" do
      job
      invoice.destroy!
      expect(interface).not_to receive(:cancel)

      job.perform
    end
  end

  describe "#error" do
    it "logs the error on the invoice" do
      expect do
        job.error(job, RuntimeError.new("Abacus down"))
      end.to change { invoice.hitobito_log_entries.count }.by(1)

      expect(invoice.hitobito_log_entries.last).to have_attributes(
        level: "error",
        category: ExternalInvoice::ERROR_CATEGORY,
        message: "Rechnung konnte nicht in Abacus storniert werden",
        payload: "Abacus down"
      )
    end
  end

  describe "#failure" do
    it "marks the invoice as error" do
      job.failure(job)

      expect(invoice.reload).to be_error
    end

    it "does nothing if the invoice has been deleted" do
      job
      invoice.destroy!

      expect { job.failure(job) }.not_to raise_error
    end
  end
end
