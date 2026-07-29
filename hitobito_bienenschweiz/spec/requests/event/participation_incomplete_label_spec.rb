# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe "Event::ParticipationDecorator#incomplete_label relevance", type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:event) { Fabricate(:course, groups: [group], kind: Event::Kind.first) }
  let(:incomplete_text) { I18n.t("event.participations.list.incomplete") }

  before do
    roles(:admin)
    sign_in(admin)
  end

  def build_participation(role_type)
    participation = event.participations.new(participant: Fabricate(:person), active: true)
    participation.roles.build(type: role_type)
    participation.save!
    participation
  end

  it "does not flag a required question as incomplete when it is irrelevant to the role" do
    # Simulates a pre-existing answer stub from before the question was marked
    # leaders-only (init_answers alone would never create this answer for a
    # participant-role registration going forward).
    question = Fabricate(:event_question, event: event, required: true, relevance: "leaders")
    participation = build_participation(Event::Course::Role::Participant.sti_name)
    participation.answers.create!(question: question)

    get group_event_participations_path(group, event)

    expect(response.body).not_to include(incomplete_text)
  end

  it "flags a required question as incomplete when it is relevant and unanswered" do
    Fabricate(:event_question, event: event, required: true, relevance: "participants")
    build_participation(Event::Course::Role::Participant.sti_name)

    get group_event_participations_path(group, event)

    expect(response.body).to include(incomplete_text)
  end

  it "does not flag anything when there are no required questions" do
    Fabricate(:event_question, event: event, required: false, relevance: "everyone")
    build_participation(Event::Course::Role::Participant.sti_name)

    get group_event_participations_path(group, event)

    expect(response.body).not_to include(incomplete_text)
  end
end
