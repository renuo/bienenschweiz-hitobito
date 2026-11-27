# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe "Event teaching staff on event pages", type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:event) do
    Fabricate(:event, groups: [group], application_opening_at: 5.days.ago,
      external_applications: true)
  end

  def add_role(role_type, first_name, label = nil, active: true)
    person = Fabricate(:person, first_name: first_name, last_name: "Muster")
    participation = Fabricate(:event_participation, event: event, participant: person,
      additional_information: "Bemerkung von #{first_name}")
    Fabricate(role_type.name.to_sym, participation: participation, label: label)
    participation.update!(active: false) unless active
  end

  before do
    add_role(Event::Role::Speaker, "Rita", "Spricht über Varroa")
    add_role(Event::Role::AssistantLeader, "Lea")
    add_role(Event::Role::Leader, "Hans", "Leitet den Kurs")
    add_role(Event::Role::Participant, "Paul", "Teilnehmer-Bemerkung")
    add_role(Event::Role::Leader, "Inaktiv", active: false)
  end

  def teaching_staff_section
    Capybara.string(response.body).find("section", text: "Leitung und Referenten")
  end

  shared_examples "lists the teaching staff" do
    it "shows name, role and label of the teaching staff in role order" do
      section = teaching_staff_section
      text = section.text
      expect(text).to include("Hauptleitung", "Hans Muster", "Leitet den Kurs")
      expect(text).to include("Leitung", "Lea Muster")
      expect(text).to include("Referent/-in", "Rita Muster", "Spricht über Varroa")
      expect(text.index("Hans Muster")).to be < text.index("Lea Muster")
      expect(text.index("Lea Muster")).to be < text.index("Rita Muster")
    end

    it "does not show participants or inactive teaching staff" do
      text = teaching_staff_section.text
      expect(text).not_to include("Paul Muster", "Teilnehmer-Bemerkung", "Inaktiv")
    end

    it "shows the participation remarks of the teaching staff only" do
      text = teaching_staff_section.text
      expect(text).to include("Bemerkung von Hans", "Bemerkung von Lea", "Bemerkung von Rita")
      expect(text).not_to include("Bemerkung von Paul", "Bemerkung von Inaktiv")
    end

    it "renders label and remark on their own lines" do
      hans = teaching_staff_section.find("dd", text: "Hans Muster")
      expect(hans).to have_css("p", text: "Leitet den Kurs")
      expect(hans).to have_css("p.multiline", text: "Bemerkung von Hans")
    end
  end

  describe "internal event page" do
    before do
      sign_in(admin)
      get group_event_path(group, event)
    end

    include_examples "lists the teaching staff"
  end

  describe "public event page" do
    before { get group_public_event_path(group, event) }

    include_examples "lists the teaching staff"
  end

  context "without teaching staff" do
    before do
      event.participations.where.not(participant_id: Person.where(first_name: "Paul"))
        .find_each(&:destroy!)
    end

    it "hides the section" do
      sign_in(admin)
      get group_event_path(group, event)
      expect(response.body).not_to include("Leitung und Referenten")
    end
  end
end
