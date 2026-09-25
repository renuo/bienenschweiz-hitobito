# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe MagazineSubscription do
  subject(:subscription) { Fabricate.build(:magazine_subscription) }

  it { is_expected.to be_valid }

  it "defaults amount to 1" do
    expect(described_class.new.amount).to eq(1)
  end

  it "is invalid without a start_date" do
    subscription.start_date = nil
    expect(subscription).not_to be_valid
  end

  it "is invalid without a subscription_type" do
    subscription.subscription_type = nil
    expect(subscription).not_to be_valid
  end

  it "is invalid with an unknown subscription_type" do
    subscription.subscription_type = "papier_abo"
    expect(subscription).not_to be_valid
  end

  it "is invalid without an amount" do
    subscription.amount = nil
    expect(subscription).not_to be_valid
  end

  it "is invalid with an amount of zero" do
    subscription.amount = 0
    expect(subscription).not_to be_valid
  end

  it "reports every mandatory field once when nothing is filled in" do
    record = described_class.new

    expect(record).not_to be_valid
    expect(record.errors.full_messages).to contain_exactly(
      "Person muss ausgefüllt werden",
      "Startdatum muss ausgefüllt werden",
      "Abomodell muss ausgefüllt werden"
    )
  end

  it "is invalid without a person" do
    subscription.person = nil
    expect(subscription).not_to be_valid
  end

  it "is valid without an end_date and cancellation_reason" do
    subscription.end_date = nil
    subscription.cancellation_reason = nil
    expect(subscription).to be_valid
  end

  it "is invalid when end_date is before start_date" do
    subscription.start_date = Date.new(2026, 5, 1)
    subscription.end_date = Date.new(2026, 4, 30)
    expect(subscription).not_to be_valid
    expect(subscription.errors[:end_date]).to be_present
  end

  it "is valid when end_date equals start_date" do
    subscription.start_date = Date.new(2026, 5, 1)
    subscription.end_date = Date.new(2026, 5, 1)
    expect(subscription).to be_valid
  end

  describe "#subscription_type_label" do
    it "translates the type" do
      subscription.subscription_type = "buchhaendler_abo"
      expect(subscription.subscription_type_label).to eq("Buchhändler-Abo")
    end
  end

  describe ".list" do
    it "orders by start_date descending" do
      person = Fabricate(:person)
      old = Fabricate(:magazine_subscription, person: person, start_date: Date.new(2024, 1, 1))
      recent = Fabricate(:magazine_subscription, person: person, start_date: Date.new(2026, 1, 1))

      expect(person.magazine_subscriptions.list).to eq([recent, old])
    end
  end

  describe ".active_on / #active_on?" do
    let(:date) { Date.new(2026, 9, 23) }

    # the export filters preloaded records in Ruby while the report filters in SQL,
    # so the two rules have to stay in step
    it "agree for every start/end combination around the date" do
      [nil, date - 1.day, date, date + 1.day].each do |end_date|
        [date - 1.day, date, date + 1.day].each do |start_date|
          record = Fabricate(:magazine_subscription, start_date: start_date,
            end_date: end_date && [end_date, start_date].max)

          expect(described_class.active_on(date).exists?(record.id))
            .to eq(record.active_on?(date)),
              "start #{start_date}, end #{record.end_date.inspect}"
        end
      end
    end
  end

  describe "#to_s" do
    it "combines type label and start date" do
      subscription.start_date = Date.new(2026, 5, 1)
      expect(subscription.to_s).to eq("Abo, 01.05.2026")
    end
  end
end
