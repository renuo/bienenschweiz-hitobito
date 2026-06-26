# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Event::Course do
  let(:kind) { Fabricate(:event_kind) }
  let(:course) {
    Fabricate(:course, kind: kind, canceled: false, application_closing_at: nil,
      maximum_participants: nil)
  }

  describe "used_attributes" do
    it "includes delivery_address and billing_address" do
      expect(Event::Course.used_attributes).to include(:delivery_address, :billing_address)
    end

    it "excludes state" do
      expect(Event::Course.used_attributes).not_to include(:state)
    end
  end

  describe "#delivery_address and #billing_address" do
    it "persists both fields" do
      course.update!(delivery_address: "Musterstrasse 1\n3000 Bern",
        billing_address: "Buchhaltung AG\n8000 Zürich")
      course.reload
      expect(course.delivery_address).to eq("Musterstrasse 1\n3000 Bern")
      expect(course.billing_address).to eq("Buchhaltung AG\n8000 Zürich")
    end
  end

  describe "#state_label" do
    context "when canceled" do
      before { course.canceled = true }

      it { expect(course.state_label).to eq(:canceled) }
    end

    context "when application_closing_at is in the past" do
      before { course.application_closing_at = Date.current - 1.day }

      it { expect(course.state_label).to eq(:expired) }
    end

    context "when application_closing_at is today" do
      before { course.application_closing_at = Date.current }

      it { expect(course.state_label).to eq(:open) }
    end

    context "when maximum_participants is reached" do
      before do
        course.maximum_participants = 2
        Fabricate(:event_participation, event: course)
        Fabricate(:event_participation, event: course)
      end

      it { expect(course.state_label).to eq(:full) }
    end

    context "when maximum_participants is not yet reached" do
      before do
        course.maximum_participants = 3
        Fabricate(:event_participation, event: course)
      end

      it { expect(course.state_label).to eq(:open) }
    end

    context "when no constraints are set" do
      it { expect(course.state_label).to eq(:open) }
    end

    context "when canceled and application_closing_at is in the past" do
      before do
        course.canceled = true
        course.application_closing_at = Date.current - 1.day
      end

      it "returns :canceled (canceled takes priority)" do
        expect(course.state_label).to eq(:canceled)
      end
    end
  end

  describe "#state" do
    it "returns the translated label for :open" do
      expect(course.state).to eq(I18n.t(:open, scope: "event_states"))
    end

    it "returns the translated label for :canceled" do
      course.canceled = true
      expect(course.state).to eq(I18n.t(:canceled, scope: "event_states"))
    end

    it "returns the translated label for :expired" do
      course.application_closing_at = Date.current - 1.day
      expect(course.state).to eq(I18n.t(:expired, scope: "event_states"))
    end

    it "returns the translated label for :full" do
      course.maximum_participants = 1
      Fabricate(:event_participation, event: course)
      expect(course.state).to eq(I18n.t(:full, scope: "event_states"))
    end
  end
end
