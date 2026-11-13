# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::CreateMagazineSubscriptionInvoicesJob do
  subject(:job) { described_class.new }

  let(:today) { Date.new(2026, 10, 7) }
  let(:enabled) { true }
  let(:person) { Fabricate(:magazine_subscriber, abacus_subject_key: 7) }
  let(:interface) { instance_double(Invoices::Abacus::SalesOrderInterface) }
  let(:subject_interface) { instance_double(Invoices::Abacus::SubjectInterface) }
  let(:submitted) { [] }

  before do
    travel_to(today)
    allow(Settings.magazine_subscription_invoicing).to receive_messages(
      enabled: enabled,
      articles: {abo: {article_number: "4711", price: 42.5}, online_abo: {article_number: "4712"}}
    )
    allow(Invoices::Abacus::Client).to receive(:new)
    allow(Invoices::Abacus::SalesOrderInterface).to receive(:new).and_return(interface)
    allow(Invoices::Abacus::SubjectInterface).to receive(:new).and_return(subject_interface)
    allow(subject_interface).to receive(:ensure_customer).and_return(true)
    allow(interface).to receive(:create_batch) do |sales_orders|
      submitted.concat(sales_orders)
      sales_orders.map do |sales_order|
        sales_order.assign_abacus_key(sales_order_id: 100 + sales_order.entity.id)
        instance_double(Invoices::Abacus::BatchResponse::Part, success?: true)
      end
    end
  end

  def subscription(start_date, **attrs)
    Fabricate(:magazine_subscription, person:, start_date:, **attrs)
  end

  it "invoices the next period of subscriptions starting within two months" do
    due = subscription(Date.new(2025, 12, 1), amount: 2)

    expect { job.perform_internal }.to change { ExternalInvoice.count }.by(1)

    invoice = due.external_invoices.first
    expect(invoice).to have_attributes(
      person: person,
      state: "open",
      period_start: Date.new(2026, 12, 1),
      issued_at: Date.new(2026, 12, 1),
      sent_at: today,
      total: 85.0,
      abacus_sales_order_key: 100 + invoice.id
    )

    position = submitted.first.positions.first
    expect(position).to have_attributes(article_number: "4711", amount: 42.5, count: 2,
      name: "Abo 01.12.2026 - 30.11.2027")
  end

  it "does not invoice subscriptions whose next period starts later" do
    subscription(Date.new(2026, 1, 1))
    subscription(Date.new(2026, 8, 1))

    expect { job.perform_internal }.not_to change { ExternalInvoice.count }
  end

  it "does not invoice the first period which is invoiced by the shop" do
    subscription(Date.new(2026, 11, 1))

    expect { job.perform_internal }.not_to change { ExternalInvoice.count }
  end

  it "does not invoice subscriptions ending before the next period" do
    subscription(Date.new(2025, 12, 1), end_date: Date.new(2026, 11, 30),
      cancellation_reason: "kint")

    expect { job.perform_internal }.not_to change { ExternalInvoice.count }
  end

  it "does not invoice types without configured article" do
    subscription(Date.new(2025, 12, 1), subscription_type: "gratis_abo")

    expect { job.perform_internal }.not_to change { ExternalInvoice.count }
  end

  it "does not invoice a period twice" do
    subscription(Date.new(2025, 12, 1))
    job.perform_internal

    expect { described_class.new.perform_internal }.not_to change { ExternalInvoice.count }
    expect(submitted.size).to eq(1)
  end

  context "when disabled" do
    let(:enabled) { false }

    it "does nothing" do
      subscription(Date.new(2025, 12, 1))

      expect { job.perform_internal }.not_to change { ExternalInvoice.count }
    end
  end

  it "makes sure the person exists as customer in Abacus once per person" do
    subscription(Date.new(2025, 12, 1))
    subscription(Date.new(2025, 11, 1))

    job.perform_internal

    expect(subject_interface).to have_received(:ensure_customer).once
      .with(having_attributes(entity: person))
    expect(submitted.size).to eq(2)
  end

  context "when the person cannot be created as customer in Abacus" do
    before do
      allow(subject_interface).to receive(:ensure_customer) do |subject|
        subject.errors[:abacus_subject_key] = :not_found_in_abacus
        false
      end
    end

    it "marks the invoice as error and logs it" do
      subscription(Date.new(2025, 12, 1))

      expect { job.perform_internal }.to change { HitobitoLogEntry.count }.by(1)

      invoice = ExternalInvoice.last
      expect(invoice).to be_error
      log = invoice.hitobito_log_entries.first
      expect(log.message).to include("nicht als Kunde in Abacus erfasst")
      expect(log.payload).to eq("Abacus Kundennummer wurde in Abacus nicht gefunden")
      expect(submitted).to be_empty
    end

    it "retries the invoice on the next run" do
      subscription(Date.new(2025, 12, 1))
      job.perform_internal
      allow(subject_interface).to receive(:ensure_customer).and_return(true)

      expect { described_class.new.perform_internal }.not_to change { ExternalInvoice.count }
      expect(ExternalInvoice.last).to be_open
    end
  end

  it "marks the invoice as error when Abacus is not reachable to check the customer" do
    subscription(Date.new(2025, 12, 1))
    allow(subject_interface).to receive(:ensure_customer).and_raise(Errno::ECONNREFUSED)

    job.perform_internal

    expect(ExternalInvoice.last).to be_error
    expect(submitted).to be_empty
  end

  it "marks the invoice as error when the article has no price" do
    subscription(Date.new(2025, 12, 1), subscription_type: "online_abo")

    job.perform_internal

    expect(ExternalInvoice.last).to be_error
    expect(HitobitoLogEntry.last.message).to include("kein Abacus Artikel")
  end

  it "marks the invoices as error when Abacus rejects them" do
    subscription(Date.new(2025, 12, 1))
    allow(interface).to receive(:create_batch) do |sales_orders|
      sales_orders.map do |sales_order|
        instance_double(Invoices::Abacus::BatchResponse::Part, success?: false,
          context_object: sales_order, error_payload: {status: 400})
      end
    end

    job.perform_internal

    expect(ExternalInvoice.last).to be_error
    expect(HitobitoLogEntry.last.payload).to eq("status" => 400)
  end

  it "marks the invoices as error when Abacus is not reachable" do
    subscription(Date.new(2025, 12, 1))
    allow(interface).to receive(:create_batch).and_raise(RestClient::InternalServerError)

    job.perform_internal

    expect(ExternalInvoice.last).to be_error
  end
end
