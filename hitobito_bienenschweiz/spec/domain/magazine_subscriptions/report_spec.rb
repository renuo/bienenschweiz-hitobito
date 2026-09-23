# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe MagazineSubscriptions::Report do
  subject(:report) { described_class.new }

  let(:person) { Fabricate(:person) }
  let(:july) { Date.new(2026, 7, 1) }
  let(:august) { Date.new(2026, 8, 1) }
  let(:september) { Date.new(2026, 9, 1) }

  def subscribe(type, start_date, end_date: nil, amount: 1)
    Fabricate(:magazine_subscription, person: person, subscription_type: type,
      start_date: start_date, end_date: end_date, amount: amount)
  end

  around { |example| travel_to(Date.new(2026, 9, 15)) { example.run } }

  describe "#months" do
    it "returns the current and the two preceding months, oldest first" do
      expect(report.months).to eq([july, august, september])
    end
  end

  describe "#categories" do
    it "reports Buchhändler, Gratis and the remaining paid types" do
      expect(report.categories).to eq(%i[buchhaendler gratis bezahlt])
    end

    it "treats every type that is neither Buchhändler nor Gratis as paid" do
      expect(described_class::CATEGORIES[:bezahlt])
        .to match_array(%w[abo abo_eur schnupper_abo online_abo geschenk_abo])
    end
  end

  describe "#amount" do
    it "counts an open subscription in every month from its start" do
      subscribe("abo", august)

      expect(report.amount(july, :bezahlt)).to eq(0)
      expect(report.amount(august, :bezahlt)).to eq(1)
      expect(report.amount(september, :bezahlt)).to eq(1)
    end

    it "stops counting after the end date" do
      subscribe("abo", july, end_date: Date.new(2026, 8, 31))

      expect(report.amount(july, :bezahlt)).to eq(1)
      expect(report.amount(august, :bezahlt)).to eq(1)
      expect(report.amount(september, :bezahlt)).to eq(0)
    end

    it "counts a subscription that starts and ends inside one month" do
      subscribe("abo", Date.new(2026, 8, 10), end_date: Date.new(2026, 8, 20))

      expect(report.amount(august, :bezahlt)).to eq(1)
      expect(report.amount(september, :bezahlt)).to eq(0)
    end

    it "ignores subscriptions starting after the reported months" do
      subscribe("abo", Date.new(2026, 10, 1))

      expect(report.months.sum { |month| report.total(month) }).to eq(0)
    end

    it "sums the Anzahl instead of counting records" do
      subscribe("buchhaendler_abo", july, amount: 20)
      subscribe("buchhaendler_abo", july, amount: 5)

      expect(report.amount(july, :buchhaendler)).to eq(25)
    end

    it "keeps the three categories apart" do
      subscribe("buchhaendler_abo", july, amount: 20)
      subscribe("gratis_abo", july, amount: 2)
      subscribe("abo", july)
      subscribe("online_abo", july)
      subscribe("geschenk_abo", july, amount: 3)

      expect(report.amount(july, :buchhaendler)).to eq(20)
      expect(report.amount(july, :gratis)).to eq(2)
      expect(report.amount(july, :bezahlt)).to eq(5)
    end
  end

  describe "#total" do
    it "sums all categories of the month" do
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
