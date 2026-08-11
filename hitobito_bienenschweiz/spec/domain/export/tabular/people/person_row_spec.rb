# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Export::Tabular::People::PersonRow do
  let(:person) { Fabricate(:person, first_name: "Alex", last_name: "Muster") }

  subject(:row) { described_class.new(person) }

  describe "gender" do
    it "exports divers as the translated label" do
      person.update!(gender: "d")
      expect(row.fetch(:gender)).to eq("divers")
    end

    it "exports the genders shipped by the core unchanged" do
      person.update!(gender: "w")
      expect(row.fetch(:gender)).to eq("weiblich")
    end
  end
end
