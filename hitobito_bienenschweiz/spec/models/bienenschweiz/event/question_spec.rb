# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe Event::Question do
  let(:event) { Fabricate(:course, groups: [groups(:root)], kind: Event::Kind.first) }
  let(:participant_person) { Fabricate(:person) }
  let(:leader_person) { Fabricate(:person) }

  let(:participation) do
    p = event.participations.new(participant: participant_person, active: true)
    p.roles.build(type: Event::Course::Role::Participant.sti_name)
    p.save!
    p
  end

  let(:leader_participation) do
    p = event.participations.new(participant: leader_person, active: true)
    p.roles.build(type: Event::Role::Leader.sti_name)
    p.save!
    p
  end

  let(:cook_participation) do
    p = event.participations.new(participant: Fabricate(:person), active: true)
    p.roles.build(type: Event::Role::Cook.sti_name)
    p.save!
    p
  end

  it "defaults to everyone" do
    question = Fabricate(:event_question, event: event)
    expect(question.relevance).to eq("everyone")
  end

  it "is invalid with a relevance outside the enum" do
    question = Fabricate.build(:event_question, event: event, relevance: "invalid")
    expect(question).not_to be_valid
  end

  describe "#relevant_for?" do
    it "is relevant for everyone when relevance is everyone" do
      question = Fabricate(:event_question, event: event, relevance: "everyone")
      expect(question.relevant_for?(participation)).to be(true)
      expect(question.relevant_for?(leader_participation)).to be(true)
    end

    it "is only relevant for participants when relevance is participants" do
      question = Fabricate(:event_question, event: event, relevance: "participants")
      expect(question.relevant_for?(participation)).to be(true)
      expect(question.relevant_for?(leader_participation)).to be(false)
    end

    it "is only relevant for leaders when relevance is leaders" do
      question = Fabricate(:event_question, event: event, relevance: "leaders")
      expect(question.relevant_for?(participation)).to be(false)
      expect(question.relevant_for?(leader_participation)).to be(true)
    end

    it "treats any non-participant role (e.g. a cook) as a leader for leaders relevance" do
      question = Fabricate(:event_question, event: event, relevance: "leaders")
      expect(question.relevant_for?(cook_participation)).to be(true)
    end
  end

  describe ".relevant_for_filter" do
    let!(:everyone_question) { Fabricate(:event_question, event: event, relevance: "everyone") }
    let!(:leaders_question) { Fabricate(:event_question, event: event, relevance: "leaders") }
    let!(:participants_question) do
      Fabricate(:event_question, event: event, relevance: "participants")
    end

    it "keeps everyone and participants questions for the participants filter" do
      result = Event::Question.relevant_for_filter("participants")
      expect(result).to include(everyone_question, participants_question)
      expect(result).not_to include(leaders_question)
    end

    it "keeps everyone and leaders questions for the teamers filter" do
      result = Event::Question.relevant_for_filter("teamers")
      expect(result).to include(everyone_question, leaders_question)
      expect(result).not_to include(participants_question)
    end

    it "keeps every question for any other filter value" do
      [nil, "all", "some_role_label"].each do |value|
        result = Event::Question.relevant_for_filter(value)
        expect(result).to include(everyone_question, leaders_question, participants_question)
      end
    end
  end
end
