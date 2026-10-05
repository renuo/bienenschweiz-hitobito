# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe MagazineSubscriptions::TrialSubscription do
  let(:person) { Fabricate(:person) }
  let(:today) { Date.new(2026, 10, 2) }

  subject(:trial) { described_class.new(person, today: today) }

  def schnupper_abo
    person.magazine_subscriptions.find_sole_by(subscription_type: "schnupper_abo")
  end

  def subscribe(start_date, **attrs)
    Fabricate(:magazine_subscription, person: person, start_date: start_date, **attrs)
  end

  context "without a subscription" do
    it "creates a one year Schnupper-Abo starting on the first of next month" do
      expect { trial.create }.to change { person.magazine_subscriptions.count }.by(1)

      expect(schnupper_abo).to have_attributes(start_date: Date.new(2026, 11, 1),
        end_date: Date.new(2027, 10, 31), amount: 1, cancellation_reason: "jahr")
    end

    it "ignores subscriptions that already ended" do
      subscribe(Date.new(2020, 1, 1), end_date: Date.new(2024, 12, 31), cancellation_reason: "kint")

      trial.create

      expect(schnupper_abo.start_date).to eq(Date.new(2026, 11, 1))
    end
  end

  context "with a running subscription" do
    let!(:subscription) { subscribe(Date.new(2025, 3, 1)) }

    it "terminates it at the end of the current billing cycle and appends the Schnupper-Abo" do
      trial.create

      expect(subscription.reload).to have_attributes(end_date: Date.new(2027, 2, 28),
        cancellation_reason: "jahr")
      expect(schnupper_abo).to have_attributes(start_date: Date.new(2027, 3, 1),
        end_date: Date.new(2028, 2, 29))
    end

    it "terminates at the end of the first cycle when the subscription starts in the future" do
      subscription.update!(start_date: Date.new(2026, 12, 1))

      trial.create

      expect(subscription.reload.end_date).to eq(Date.new(2027, 11, 30))
      expect(schnupper_abo.start_date).to eq(Date.new(2027, 12, 1))
    end

    it "terminates on the last day of a cycle ending today" do
      subscription.update!(start_date: Date.new(2025, 10, 3))

      trial.create

      expect(subscription.reload.end_date).to eq(today)
      expect(schnupper_abo.start_date).to eq(Date.new(2026, 10, 3))
    end
  end

  context "with multiple running subscriptions" do
    let!(:later) { subscribe(Date.new(2024, 6, 1)) }
    let!(:sooner) { subscribe(Date.new(2023, 1, 1)) }

    it "terminates only the one whose billing cycle ends first" do
      trial.create

      expect(sooner.reload.end_date).to eq(Date.new(2026, 12, 31))
      expect(later.reload.end_date).to be_nil
      expect(schnupper_abo.start_date).to eq(Date.new(2027, 1, 1))
    end
  end

  it "does nothing when the person already got a Schnupper-Abo" do
    subscribe(Date.new(2025, 1, 1), subscription_type: "schnupper_abo",
      end_date: Date.new(2025, 12, 31), cancellation_reason: "jahr")
    running = subscribe(Date.new(2024, 1, 1))

    expect { trial.create }.not_to change { person.magazine_subscriptions.count }
    expect(running.reload.end_date).to be_nil
  end
end
