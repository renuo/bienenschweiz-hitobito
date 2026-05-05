# frozen_string_literal: true

#  Copyright (c) 2023, BienenSchweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require "spec_helper"

RSpec.describe PeopleController, type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#show" do
    let(:person) {
      Fabricate(:person, hive_count: "around 8", honey_yield: "a bunch", export_to_website: false,
        num_ad_boards: 66, salutation: "the very magnificent")
    }

    before do
      Fabricate(:role, person:, group:, type: Group::Dachverband::Supervisor.sti_name)
    end

    it "shows the added fields" do
      get group_person_path(group, person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.last_name)
      expect(response.body).to include("around 8")
      expect(response.body).to include("a bunch")
      expect(response.body).to include("66")
      expect(response.body).to include("the very magnificent")
    end
  end

  describe "#update" do
    let(:person) { Fabricate(:person) }
    let(:person_params) do
      {
        first_name: "Max",
        last_name: "Muster",
        email: "test@example.com",
        hive_count: "7-9",
        honey_yield: "42 Liter",
        export_to_website: false,
        num_ad_boards: 5,
        salutation: "Dear Max"
      }
    end

    before do
      Fabricate(:role, person:, group:, type: Group::Dachverband::Supervisor.sti_name)
    end

    it "updates the person with the added fields" do
      expect do
        patch "/groups/#{group.id}/people/#{person.id}", params: {person: person_params}
      end.not_to change { Person.count }

      person.reload
      expect(person).to be_present
      expect(person.hive_count).to eq("7-9")
      expect(person.honey_yield).to eq("42 Liter")
      expect(person.export_to_website).to eq(false)
      expect(person.num_ad_boards).to eq(5)
      expect(person.salutation).to eq("Dear Max")
    end
  end
end
