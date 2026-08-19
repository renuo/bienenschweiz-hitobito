# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Import::Person do
  # The wagon redefines Person's gender setter after adding the gender, which is
  # what lets a CSV import supply either the key or the translated label.
  describe "gender" do
    def import(gender)
      ::Person.new.tap do |person|
        Import::Person.new(person, {"first_name" => "Alex", "gender" => gender}).populate
      end
    end

    it "imports the translated value divers" do
      person = import("divers")
      expect(person.gender).to eq("d")
      expect(person).to be_valid
    end

    it "imports the translated value case insensitively" do
      expect(import("Divers").gender).to eq("d")
    end

    it "imports the key divers" do
      person = import("d")
      expect(person.gender).to eq("d")
      expect(person).to be_valid
    end

    it "still imports the genders shipped by the core" do
      expect(import("weiblich").gender).to eq("w")
      expect(import("männlich").gender).to eq("m")
    end

    it "rejects an unknown gender" do
      person = import("unbekanntes geschlecht")
      expect(person).not_to be_valid
      expect(person.errors[:gender]).to be_present
    end
  end
end
