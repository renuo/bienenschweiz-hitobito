# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Salutation do
  let(:person) { Fabricate(:person, gender: "d", first_name: "Alex", last_name: "Muster") }

  describe "#value" do
    it "greets a person with gender divers" do
      expect(Salutation.new(person).value).to eq("Hallo Alex")
    end

    it "greets a person with gender divers with the personal salutation" do
      expect(Salutation.new(person, "lieber_vorname").value).to eq("Liebe*r Alex")
    end

    it "has a value for every gender and salutation" do
      Person::GENDERS.each do |gender|
        person.update!(gender: gender)
        Salutation.all.each_key do |salutation|
          expect { Salutation.new(person, salutation).value }
            .not_to raise_error, "missing salutation '#{salutation}' for gender '#{gender}'"
        end
      end
    end
  end

  describe "#value_for_household" do
    let(:housemate) { Fabricate(:person, gender: "w", first_name: "Maja") }

    it "joins the salutations of a divers and a female person" do
      expect(Salutation.new(person, "lieber_vorname").value_for_household([person, housemate]))
        .to eq("Liebe*r Alex, liebe Maja")
    end
  end
end
