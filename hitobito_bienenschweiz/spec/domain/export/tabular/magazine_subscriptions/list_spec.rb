# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Export::Tabular::MagazineSubscriptions::List do
  let(:today) { Date.new(2026, 9, 23) }

  subject(:list) { described_class.new(date: today) }

  let(:subscriber) do
    Fabricate(:person, first_name: "Anna", last_name: "Muster", salutation: "Frau",
      address_care_of: "c/o Imkerei", street: "Bienenweg", housenumber: "7b",
      postbox: "Postfach 42", zip_code: "3000", town: "Bern", country: "CH")
  end

  def subscribe(person, type, start_date: today - 1.month, end_date: nil, amount: 1)
    Fabricate(:magazine_subscription, person: person, subscription_type: type,
      start_date: start_date, end_date: end_date, amount: amount)
  end

  def rows
    list.data_rows.to_a
  end

  def row_for(person)
    index = list.list.index(person)
    rows[index]
  end

  def value(person, attr)
    row_for(person)[list.attributes.index(attr)]
  end

  describe "#attribute_labels" do
    it "splits the postal address into its own columns" do
      expect(list.attributes).to eq(%i[salutation first_name last_name company_name
        address_care_of street housenumber postbox zip_code town country
        subscriptions total_amount])
    end

    it "labels the computed columns" do
      expect(list.labels.last(2)).to eq(["Abos", "Total Anzahl"])
    end
  end

  describe "rows" do
    it "exports one row per person, not per subscription" do
      subscribe(subscriber, "abo")
      subscribe(subscriber, "gratis_abo")

      expect(rows.size).to eq(1)
    end

    it "exports the full postal address" do
      subscribe(subscriber, "abo")

      expect(value(subscriber, :salutation)).to eq("Frau")
      expect(value(subscriber, :first_name)).to eq("Anna")
      expect(value(subscriber, :last_name)).to eq("Muster")
      expect(value(subscriber, :address_care_of)).to eq("c/o Imkerei")
      expect(value(subscriber, :street)).to eq("Bienenweg")
      expect(value(subscriber, :housenumber)).to eq("7b")
      expect(value(subscriber, :postbox)).to eq("Postfach 42")
      expect(value(subscriber, :zip_code)).to eq("3000")
      expect(value(subscriber, :town)).to eq("Bern")
      expect(value(subscriber, :country)).to eq("Schweiz")
    end

    it "names each subscription with its Anzahl" do
      subscribe(subscriber, "abo", amount: 2)
      subscribe(subscriber, "buchhaendler_abo", amount: 20)

      expect(value(subscriber, :subscriptions)).to eq("Abo (2), Buchhändler-Abo (20)")
    end

    it "totals the Anzahl over all active subscriptions" do
      subscribe(subscriber, "abo", amount: 2)
      subscribe(subscriber, "buchhaendler_abo", amount: 20)

      expect(value(subscriber, :total_amount)).to eq(22)
    end
  end

  describe "active subscriptions only" do
    it "excludes a person whose subscriptions have all ended" do
      subscribe(subscriber, "abo", start_date: today - 1.year, end_date: today - 1.day)

      expect(rows).to be_empty
    end

    it "excludes a person whose subscription starts later" do
      subscribe(subscriber, "abo", start_date: today + 1.day)

      expect(rows).to be_empty
    end

    it "includes a subscription ending exactly today" do
      subscribe(subscriber, "abo", start_date: today - 1.year, end_date: today)

      expect(value(subscriber, :total_amount)).to eq(1)
    end

    it "leaves an ended subscription out of an otherwise active person's row" do
      subscribe(subscriber, "abo", amount: 2)
      subscribe(subscriber, "gratis_abo", start_date: today - 1.year, end_date: today - 1.day,
        amount: 5)

      expect(value(subscriber, :subscriptions)).to eq("Abo (2)")
      expect(value(subscriber, :total_amount)).to eq(2)
    end
  end

  describe "ordering" do
    it "sorts by last name, then first name" do
      zeller = Fabricate(:person, first_name: "Anna", last_name: "Zeller")
      aebi_beat = Fabricate(:person, first_name: "Beat", last_name: "Aebi")
      aebi_anna = Fabricate(:person, first_name: "Anna", last_name: "Aebi")
      [zeller, aebi_beat, aebi_anna].each { |person| subscribe(person, "abo") }

      expect(list.list.map(&:to_s)).to eq([aebi_anna, aebi_beat, zeller].map(&:to_s))
    end
  end

  describe ".csv" do
    it "renders a header row and one data row per subscriber" do
      subscribe(subscriber, "abo", amount: 3)

      # the generator writes a BOM and uses ";" so Excel opens it directly
      csv = CSV.parse(described_class.csv(date: today).delete_prefix("\uFEFF"), col_sep: ";")

      expect(csv.first).to include("Abos", "Total Anzahl", "PLZ", "Ort")
      expect(csv.size).to eq(2)
      expect(csv.second).to include("Muster", "Bern", "Abo (3)", "3")
    end
  end
end
