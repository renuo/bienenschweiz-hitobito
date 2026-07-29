# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Event::BulkAnswersHelper, type: :helper do
  let(:event) { Fabricate(:course, groups: [groups(:root)], kind: Event::Kind.first) }

  def build_participation(role_type)
    p = event.participations.new(participant: Fabricate(:person), active: true)
    p.roles.build(type: role_type)
    p.save!
    p
  end

  describe "#participation_label" do
    it "never annotates on a participants-only question, even with a leader role" do
      question = Fabricate(:event_question, event: event, relevance: "participants")
      participation = build_participation(Event::Course::Role::Participant.sti_name)
      Fabricate(:"Event::Role::Leader", participation: participation)

      expect(helper.participation_label(participation, question)).to eq(participation.to_s)
    end

    shared_examples "annotates non-participant roles" do
      it "does not annotate when every role is a basic participant" do
        participation = build_participation(Event::Course::Role::Participant.sti_name)

        expect(helper.participation_label(participation, question)).to eq(participation.to_s)
      end

      it "annotates with the translated role for a non-participant role" do
        participation = build_participation(Event::Role::Leader.sti_name)

        expect(helper.participation_label(participation, question)).to eq(
          "#{participation} (#{Event::Role::Leader.label})"
        )
      end

      it "uses the role's own to_s when it has a custom label" do
        participation = build_participation(Event::Role::Leader.sti_name)
        role = participation.roles.first
        role.update!(label: "Küche")

        expect(helper.participation_label(participation, question)).to eq(
          "#{participation} (#{role})"
        )
      end
    end

    context "on a leaders-only question" do
      let(:question) { Fabricate(:event_question, event: event, relevance: "leaders") }

      include_examples "annotates non-participant roles"
    end

    context "on a question relevant to everyone" do
      let(:question) { Fabricate(:event_question, event: event, relevance: "everyone") }

      include_examples "annotates non-participant roles"
    end
  end
end
