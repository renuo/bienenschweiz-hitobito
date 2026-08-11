# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Person::Filter::List do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }

  let!(:divers) { create_person("d") }
  let!(:female) { create_person("w") }

  def create_person(gender)
    Fabricate(Group::Dachverband::AdministratorBienenSchweiz.sti_name.to_sym, group: group)
      .person.tap { |person| person.update!(gender: gender) }
  end

  def filtered_by(gender)
    described_class.new(group, admin,
      filters: {attributes: {"1" => {key: "gender", constraint: "equal", value: gender}}},
      range: "deep").entries
  end

  # The gender filter is built from Person::GENDERS, so adding divers makes it
  # selectable in the people list filter.
  it "finds people with gender divers" do
    expect(filtered_by("d")).to include(divers)
    expect(filtered_by("d")).not_to include(female)
  end

  it "does not return divers people when filtering for another gender" do
    expect(filtered_by("w")).to include(female)
    expect(filtered_by("w")).not_to include(divers)
  end

  it "offers divers as a filter option" do
    options = (Person::GENDERS + [""]).collect { |g| [g, Person.new.gender_label(g)] }
    expect(options).to include(["d", "divers"])
  end
end
