# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe MagazineSubscriptions::Report do
  subject(:report) { described_class.new(today: today) }

  let(:today) { Date.new(2026, 9, 15) }
  let(:person) { Fabricate(:magazine_subscriber) }
  let(:july) { Date.new(2026, 7, 1) }
  let(:august) { Date.new(2026, 8, 1) }
  let(:september) { Date.new(2026, 9, 1) }

  def subscribe(type, start_date, end_date: nil, amount: 1)
    Fabricate(:magazine_subscription, person: person, subscription_type: type,
      start_date: start_date, end_date: end_date, amount: amount,
      cancellation_reason: end_date ? "biwe" : nil)
  end

  describe "#months" do
    it "includes the current month on the 15th and returns 18 months newest first" do
      expect(report.months).to eq(Array.new(18) { |index| Date.new(2025, 4, 1) >> index }.reverse)
    end

    context "before the 15th" do
      let(:today) { Date.new(2026, 9, 14) }

      it "starts with the previous month" do
        expect(report.months).to eq(Array.new(18) { |index| Date.new(2025, 3, 1) >> index }.reverse)
      end
    end
  end

  describe "#paid_amount" do
    it "counts an open subscription in every month from its start" do
      subscribe("abo", august)

      expect(report.paid_amount(july)).to eq(0)
      expect(report.paid_amount(august)).to eq(1)
      expect(report.paid_amount(september)).to eq(1)
    end

    it "stops counting after the end date" do
      subscribe("abo", july, end_date: Date.new(2026, 8, 31))

      expect(report.paid_amount(july)).to eq(1)
      expect(report.paid_amount(august)).to eq(1)
      expect(report.paid_amount(september)).to eq(0)
    end

    it "only counts subscriptions active on the 15th, including starts and ends on that date" do
      subscribe("abo", Date.new(2026, 8, 15), amount: 2)
      subscribe("abo", august, end_date: Date.new(2026, 8, 15), amount: 3)
      subscribe("abo", august, end_date: Date.new(2026, 8, 14), amount: 7)
      subscribe("abo", Date.new(2026, 8, 16), amount: 11)

      expect(report.paid_amount(august)).to eq(5)
      expect(report.paid_amount(september)).to eq(13)
    end

    it "ignores subscriptions starting after the reported months" do
      subscribe("abo", Date.new(2026, 10, 1))

      expect(report.months.sum { |month| report.total(month) }).to eq(0)
    end

    it "sums the paid types and excludes Buchhändler and Gratis" do
      subscribe("buchhaendler_abo", july, amount: 20)
      subscribe("gratis_abo", july, amount: 2)
      subscribe("abo", july)
      subscribe("abo_eur", july, amount: 4)
      subscribe("schnupper_abo", july, amount: 2)
      subscribe("online_abo", july)
      Fabricate(:magazine_subscription, person: person, subscription_type: "geschenk_abo",
        start_date: july, amount: 3, gifter: Fabricate(:person))

      expect(report.paid_amount(july)).to eq(11)
    end
  end

  describe "#types" do
    it "lists every subscription type" do
      expect(report.types).to match_array(MagazineSubscription::SUBSCRIPTION_TYPES)
    end
  end

  describe "#type_amount" do
    it "sums the Anzahl per subscription type" do
      subscribe("abo", july, amount: 3)
      subscribe("abo", august, amount: 2)
      subscribe("online_abo", july)

      expect(report.type_amount(july, "abo")).to eq(3)
      expect(report.type_amount(august, "abo")).to eq(5)
      expect(report.type_amount(august, "online_abo")).to eq(1)
      expect(report.type_amount(august, "abo_eur")).to eq(0)
    end
  end

  describe "#total" do
    it "sums all subscription types for the month" do
      subscribe("buchhaendler_abo", august, amount: 20)
      subscribe("gratis_abo", august, amount: 2)
      subscribe("abo", august, amount: 3)

      expect(report.total(august)).to eq(25)
    end

    it "is zero for a month without subscriptions" do
      expect(report.total(july)).to eq(0)
    end
  end
end
