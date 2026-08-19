# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Event::Guest do
  # Event::Guest derives its gender enum and setter from Person::GENDERS, so the
  # gender added by the wagon applies to guests as well.
  describe "gender" do
    it "allows divers as gender" do
      guest = Fabricate.build(:event_guest, gender: "d")
      expect(guest).to be_valid
      expect(guest.gender_label).to eq("divers")
    end

    it "offers divers as an option" do
      expect(Event::Guest.gender_labels).to include(d: "divers")
    end

    it "converts the translated value to divers" do
      guest = Event::Guest.new
      guest.gender = "divers"
      expect(guest.gender).to eq("d")
    end

    # The setter translates every possible value on each assignment, so a gender
    # without an Event::Guest translation breaks the pre-existing genders too.
    Person::GENDERS.each do |gender|
      it "accepts #{gender} as gender" do
        guest = Event::Guest.new
        expect { guest.gender = gender }.not_to raise_error
        expect(guest.gender).to eq(gender)
      end
    end

    it "has a label for every gender" do
      Person::GENDERS.each do |gender|
        expect { Event::Guest.new.gender_label(gender) }
          .not_to raise_error, "missing label for gender '#{gender}'"
      end
    end
  end
end
