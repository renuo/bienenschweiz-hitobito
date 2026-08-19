# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Bienenschweiz::Genders do
  describe ".register!" do
    it "has added divers to the genders on boot" do
      expect(Person::GENDERS).to include("d")
    end

    # to_prepare runs on every reload cycle in development, so registering twice
    # must not grow the list — duplicates would show up as duplicate options in
    # the gender radio buttons and select fields.
    it "does not add divers again when registering repeatedly" do
      expect { 2.times { described_class.register! } }
        .not_to change { Person::GENDERS.dup }
      expect(Person::GENDERS.count("d")).to eq(1)
    end

    it "keeps the setter accepting the translated value after registering again" do
      described_class.register!
      person = Person.new
      person.gender = "divers"
      expect(person.gender).to eq("d")
    end
  end
end
