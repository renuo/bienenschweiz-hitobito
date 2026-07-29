# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe Event::Answer do
  let(:event) { Fabricate(:course, groups: [groups(:root)], kind: Event::Kind.first) }

  def build_participation(role_type)
    participation = event.participations.new(participant: Fabricate(:person), active: true,
      enforce_required_answers: true)
    participation.roles.build(type: role_type)
    participation
  end

  it "does not require an answer for a required question irrelevant to the participation's role" do
    question = Fabricate(:event_question, event: event, required: true, relevance: "leaders")
    participation = build_participation(Event::Course::Role::Participant.sti_name)
    answer = question.answers.new(question: question, participation: participation)

    expect(answer).to be_valid
  end

  it "still requires an answer for a required question relevant to the participation's role" do
    question = Fabricate(:event_question, event: event, required: true, relevance: "participants")
    participation = build_participation(Event::Course::Role::Participant.sti_name)
    answer = question.answers.new(question: question, participation: participation)

    expect(answer).not_to be_valid
    expect(answer.errors[:answer]).to be_present
  end

  it "still requires an answer for a required question relevant to everyone" do
    question = Fabricate(:event_question, event: event, required: true, relevance: "everyone")
    participation = build_participation(Event::Role::Leader.sti_name)
    answer = question.answers.new(question: question, participation: participation)

    expect(answer).not_to be_valid
  end

  it "does not require an answer that has no associated question" do
    participation = build_participation(Event::Course::Role::Participant.sti_name)
    answer = Event::Answer.new(question: nil, participation: participation)

    expect(answer.answer_required?).to be_falsey
  end

  it "does not enforce presence when enforce_required_answers is false" do
    question = Fabricate(:event_question, event: event, required: true, relevance: "participants")
    participation = event.participations.new(participant: Fabricate(:person), active: true)
    participation.roles.build(type: Event::Course::Role::Participant.sti_name)
    answer = question.answers.new(question: question, participation: participation)

    expect(answer).to be_valid
  end
end
