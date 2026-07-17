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

  describe "#kas_instructor_fees_created_for_current_year?" do
    it "returns false when the array is empty" do
      expect(course.kas_instructor_fees_created_for_current_year?).to be false
    end

    it "returns true when the current year is in the array" do
      course.update_column(:kas_instructor_fees_created_years, [Time.zone.today.year])
      expect(course.kas_instructor_fees_created_for_current_year?).to be true
    end

    it "returns false when only other years are in the array" do
      course.update_column(:kas_instructor_fees_created_years, [Time.zone.today.year - 1])
      expect(course.kas_instructor_fees_created_for_current_year?).to be false
    end
  end

  describe "#kas_fees_creatable?" do
    context "when kind is nil" do
      it "returns falsy" do
        course.kind = nil
        expect(course.kas_fees_creatable?).to be_falsy
      end
    end
  end

  describe "#kas_instructor_fees_creatable?" do
    let(:instructor_kind) { Fabricate(:event_kind, kas_instructor_fees: true, kas_fee_code: "X") }
    let(:instructor_course) {
      Fabricate(:course, kind: instructor_kind, canceled: false,
        application_closing_at: nil, maximum_participants: nil)
    }

    it "returns true when configured and current year not yet created" do
      expect(instructor_course.kas_instructor_fees_creatable?).to be true
    end

    it "returns false when current year already created" do
      instructor_course.update_column(:kas_instructor_fees_created_years, [Time.zone.today.year])
      expect(instructor_course.kas_instructor_fees_creatable?).to be false
    end

    context "when kind is nil" do
      it "returns falsy" do
        course.kind = nil
        expect(course.kas_instructor_fees_creatable?).to be_falsy
      end
    end
  end

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

  describe "#recalc_number" do
    let(:group) { Fabricate(:kantonalverband, code: 42) }
    let(:kind) { Fabricate(:event_kind, abbreviation: "BK") }

    def make_course(groups: [group], date: Time.zone.local(2024, 6, 15), course_kind: kind)
      course = Fabricate.build(:course, groups: groups, kind: course_kind)
      course.dates.build(start_at: date)
      course.save!
      course
    end

    it "uses the kind abbreviation as prefix" do
      expect(make_course.number).to eq("BK-42-2024")
    end

    it "uses a different abbreviation when the kind has one" do
      gk = Fabricate(:event_kind, abbreviation: "GK")
      expect(make_course(course_kind: gk).number).to eq("GK-42-2024")
    end

    it "joins multiple group codes with /" do
      group2 = Fabricate(:kantonalverband, code: 99)
      expect(make_course(groups: [group, group2]).number).to eq("BK-42/99-2024")
    end

    it "derives the year from start_at" do
      expect(make_course(date: Time.zone.local(2023, 1, 1)).number).to eq("BK-42-2023")
    end

    it "uses empty string for a group without a code" do
      no_code_group = Fabricate(:kantonalverband, code: nil)
      expect(make_course(groups: [no_code_group]).number).to eq("BK--2024")
    end

    it "recalculates on every save" do
      course = make_course(date: Time.zone.local(2024, 6, 15))
      group2 = Fabricate(:kantonalverband, code: 77)
      course.groups = [group2]
      course.save!
      expect(course.number).to eq("BK-77-2024")
    end
  end
end
