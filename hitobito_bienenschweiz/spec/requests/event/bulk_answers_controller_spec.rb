# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe Event::BulkAnswersController, type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:event) { Fabricate(:event, groups: [group]) }
  let(:question) { Fabricate(:event_question, event: event, question: "Allergien?") }
  let(:participant) { Fabricate(:person) }
  let!(:participation) do
    Fabricate(:event_participation, event: event, participant: participant, active: true)
  end

  before do
    roles(:admin)
    sign_in(admin)
    question
  end

  let(:answer) { participation.answers.find_by(question: question) }

  describe "GET #edit" do
    it "renders successfully" do
      get edit_group_event_bulk_answers_path(group, event)
      expect(response).to have_http_status(:ok)
    end

    it "shows the question text" do
      get edit_group_event_bulk_answers_path(group, event)
      expect(response.body).to include("Allergien?")
    end

    it "shows the participant name" do
      get edit_group_event_bulk_answers_path(group, event)
      expect(response.body).to include(participant.full_name)
    end

    context "as unauthorized person" do
      let(:other_person) { Fabricate(:person) }

      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect do
          get edit_group_event_bulk_answers_path(group, event)
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "participations index" do
    it "shows the bulk edit button for admin" do
      get group_event_participations_path(group, event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(edit_group_event_bulk_answers_path(group, event))
      expect(response.body).to include("Administrationsangaben bearbeiten")
    end
  end

  describe "PATCH #update" do
    it "updates the text answer and redirects" do
      patch group_event_bulk_answers_path(group, event),
        params: {answers: {answer.id.to_s => {answer: "Keine"}}}
      expect(answer.reload.answer).to eq("Keine")
      expect(response).to redirect_to(edit_group_event_bulk_answers_path(group, event))
    end

    it "ignores answer ids not belonging to this event" do
      other_event = Fabricate(:event, groups: [group])
      other_question = Fabricate(:event_question, event: other_event, question: "Andere Frage?")
      other_participant = Fabricate(:person)
      other_participation = Fabricate(:event_participation,
        event: other_event, participant: other_participant, active: true)
      other_answer = other_participation.answers.find_by(question: other_question)

      patch group_event_bulk_answers_path(group, event),
        params: {answers: {other_answer.id.to_s => {answer: "Hack"}}}

      expect(other_answer.reload.answer).not_to eq("Hack")
    end

    context "as unauthorized person" do
      let(:other_person) { Fabricate(:person) }

      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect do
          patch group_event_bulk_answers_path(group, event), params: {answers: {}}
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
