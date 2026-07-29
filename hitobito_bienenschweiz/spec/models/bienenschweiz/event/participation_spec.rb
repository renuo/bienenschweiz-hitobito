# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe Event::Participation do
  let(:event) { Fabricate(:course, groups: [groups(:root)], kind: Event::Kind.first) }

  let!(:leaders_question) do
    Fabricate(:event_question, event: event, question: "Leaders only", relevance: "leaders")
  end
  let!(:participants_question) do
    Fabricate(:event_question, event: event, question: "Participants only",
      relevance: "participants")
  end
  let!(:everyone_question) do
    Fabricate(:event_question, event: event, question: "Everyone", relevance: "everyone")
  end

  def build_participation(role_type)
    participation = event.participations.new(participant: Fabricate(:person), active: true)
    participation.roles.build(type: role_type)
    participation
  end

  it "only builds answers for questions relevant to a registering participant" do
    participation = build_participation(Event::Course::Role::Participant.sti_name)

    participation.init_answers

    questions = participation.answers.map(&:question)
    expect(questions).to include(participants_question, everyone_question)
    expect(questions).not_to include(leaders_question)
  end

  it "only builds answers for questions relevant to a registering leader" do
    participation = build_participation(Event::Role::Leader.sti_name)

    participation.init_answers

    questions = participation.answers.map(&:question)
    expect(questions).to include(leaders_question, everyone_question)
    expect(questions).not_to include(participants_question)
  end

  it "does not duplicate an already built answer for the same question" do
    participation = build_participation(Event::Course::Role::Participant.sti_name)
    participation.answers << everyone_question.answers.new(question: everyone_question)

    participation.init_answers

    matching = participation.answers.select { |a| a.question_id == everyone_question.id }
    expect(matching.size).to eq(1)
  end
end
