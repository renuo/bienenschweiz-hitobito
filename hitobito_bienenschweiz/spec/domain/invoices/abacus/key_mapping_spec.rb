# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::KeyMapping do
  let!(:linked) { Fabricate(:magazine_subscriber, abacus_subject_key: 4711) }
  let!(:unlinked) { Fabricate(:person) }
  let(:subscription) do
    Fabricate(:magazine_subscription, person: linked, start_date: Date.new(2025, 12, 1))
  end
  let!(:invoice) do
    ExternalInvoice::Magazine.create!(person: linked, link: subscription, total: 85,
      state: :open, period_start: Date.new(2026, 12, 1), issued_at: Date.new(2026, 12, 1),
      sent_at: Date.new(2026, 10, 7), abacus_sales_order_key: 99)
  end

  # Simulates the export from another instance via JSON.
  let(:exported) { JSON.parse(JSON.generate(described_class.export)) }

  def import(data = exported, **opts)
    described_class.new(data, **opts).import
  end

  def reset_links
    Person.update_all(abacus_subject_key: nil) # rubocop:disable Rails/SkipsModelValidations
    ExternalInvoice.delete_all
  end

  describe ".export" do
    it "exports linked people and invoices" do
      expect(exported["people"]).to eq([{
        "id" => linked.id, "abacus_subject_key" => 4711,
        "first_name" => linked.first_name, "last_name" => linked.last_name,
        "company_name" => linked.company_name
      }])
      expect(exported["external_invoices"].size).to eq(1)
      expect(exported["external_invoices"].first)
        .to include("link_type" => "MagazineSubscription", "link_id" => subscription.id,
          "abacus_sales_order_key" => 99, "state" => "open", "period_start" => "2026-12-01")
    end
  end

  describe "#import" do
    it "restores the subject and sales order keys" do
      data = exported
      reset_links

      result = import(data)

      expect(result.people).to eq(1)
      expect(result.invoices).to eq(1)
      expect(result.skipped).to be_empty
      expect(linked.reload.abacus_subject_key).to eq(4711)
      expect(unlinked.reload.abacus_subject_key).to be_nil
      restored = ExternalInvoice.find_by!(link: subscription)
      expect(restored).to have_attributes(type: "ExternalInvoice::Magazine", state: "open",
        abacus_sales_order_key: 99, total: 85, period_start: Date.new(2026, 12, 1))
    end

    it "updates an existing invoice for the same period" do
      data = exported
      invoice.update!(state: :error, abacus_sales_order_key: nil)

      expect { import(data) }.not_to change(ExternalInvoice, :count)
      expect(invoice.reload).to have_attributes(state: "open", abacus_sales_order_key: 99)
    end

    it "skips people whose name does not match" do
      data = exported
      reset_links
      linked.update!(first_name: "Someone else")

      result = import(data)

      expect(result.people).to eq(0)
      expect(result.skipped).to include(a_string_matching(/Person #{linked.id}: name mismatch/))
      expect(linked.reload.abacus_subject_key).to be_nil
    end

    it "skips keys already used by another person" do
      data = exported
      reset_links
      unlinked.update!(abacus_subject_key: 4711)

      result = import(data)

      expect(result.skipped).to include(a_string_matching(/already used by person #{unlinked.id}/))
      expect(linked.reload.abacus_subject_key).to be_nil
    end

    it "skips invoices whose subscription belongs to another person" do
      data = exported
      reset_links
      subscription.update_column(:person_id, unlinked.id) # rubocop:disable Rails/SkipsModelValidations

      result = import(data)

      expect(result.invoices).to eq(0)
      expect(result.skipped).to include(a_string_matching(/belongs to other person/))
    end

    it "changes nothing in dry run" do
      data = exported
      reset_links

      result = import(data, dry_run: true)

      expect(result.people).to eq(1)
      expect(linked.reload.abacus_subject_key).to be_nil
      expect(ExternalInvoice.count).to eq(0)
    end

    it "skips people that do not exist" do
      data = exported
      data["people"].first["id"] = -1

      result = import(data)

      expect(result.skipped).to include("Person -1: not found")
    end

    it "replaces a different key and logs it" do
      data = exported
      linked.update_column(:abacus_subject_key, 1234) # rubocop:disable Rails/SkipsModelValidations
      log = []

      result = import(data, logger: log.method(:<<))

      expect(result.people).to eq(1)
      expect(linked.reload.abacus_subject_key).to eq(4711)
      expect(log).to include("Person #{linked.id}: replacing key 1234 with 4711")
    end

    it "skips invoices whose subscription does not exist" do
      data = exported
      data["external_invoices"].first["link_id"] = -1

      result = import(data)

      expect(result.invoices).to eq(0)
      expect(result.skipped)
        .to include(a_string_matching(/MagazineSubscription -1 .*: link not found/))
    end

    it "skips invoices with an unknown link type" do
      data = exported
      data["external_invoices"].first["link_type"] = "Unknown"
      log = []

      result = import(data, logger: log.method(:<<))

      expect(result.invoices).to eq(0)
      expect(log).to include(a_string_matching(/SKIPPED Invoice Unknown .*: link not found/))
    end

    it "rejects unknown versions" do
      expect { import(exported.merge("version" => 2)) }.to raise_error(ArgumentError)
    end
  end
end
