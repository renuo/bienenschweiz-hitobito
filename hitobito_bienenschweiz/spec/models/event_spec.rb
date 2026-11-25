# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Event do
  describe "#event_type" do
    let(:event) { Fabricate.build(:event, dates: [Event::Date.new(start_at: Time.zone.now)]) }

    it "is required" do
      event.event_type = nil
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to be_present
    end

    it "accepts the defined types" do
      %w[public online internal].each do |type|
        event.event_type = type
        expect(event).to be_valid
      end
    end

    it "rejects unknown types" do
      event.event_type = "secret"
      expect(event).not_to be_valid
    end

    it "has translated labels" do
      event.event_type = "internal"
      expect(event.event_type_label).to eq "Intern"
    end

    it "has no default" do
      expect(Event.new.event_type).to be_nil
    end

    it "is not required for courses" do
      course = Fabricate.build(:course, event_type: nil)
      course.valid?
      expect(course.errors[:event_type]).to be_empty
    end
  end
end
