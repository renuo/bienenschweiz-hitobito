# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe Event::BulkAnswersController, type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:event_kind) { Event::Kind.first }
  let(:event) { Fabricate(:course, groups: [group], kind: event_kind) }
  let(:question) { Fabricate(:event_question, event: event, question: "Allergien?", admin: true) }
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

    context "when there are no admin questions" do
      let!(:question) { nil }

      it "shows no-questions message" do
        get edit_group_event_bulk_answers_path(group, event)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("event.bulk_answers.edit.no_questions"))
      end
    end

    context "with a required question" do
      let!(:required_question) do
        Fabricate(:event_question, event: event, question: "Pflichtfrage?", admin: true,
          required: true)
      end

      it "shows the required marker" do
        get edit_group_event_bulk_answers_path(group, event)
        expect(response.body).to include("*")
      end
    end

    context "with a choice question" do
      let!(:choice_question) do
        Fabricate(:event_question, event: event, question: "Lieblingsfarbe?", admin: true,
          choices: "Rot, Grün, Blau")
      end

      it "shows radio buttons for each choice" do
        get edit_group_event_bulk_answers_path(group, event)
        expect(response.body).to include("Rot")
        expect(response.body).to include("Grün")
      end
    end

    context "question visibility" do
      let!(:non_admin_question) do
        Fabricate(:event_question, event: event, question: "Diätvorschriften?", admin: false)
      end

      it "shows admin questions" do
        get edit_group_event_bulk_answers_path(group, event)
        expect(response.body).to include("Allergien?")
      end

      it "does not show non-admin questions" do
        get edit_group_event_bulk_answers_path(group, event)
        expect(response.body).not_to include("Diätvorschriften?")
      end
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

    it "forwards the active participant_type filter to the bulk edit button" do
      get group_event_participations_path(group, event, filters: {participant_type: "teamers"})

      expect(response.body).to include(
        edit_group_event_bulk_answers_path(group, event, filters: {participant_type: "teamers"})
      )
    end
  end

  describe "GET #edit with a participant_type filter" do
    let!(:teamer_participation) do
      Fabricate(:event_participation, event: event, active: true).tap do |p|
        Fabricate(:"Event::Role::Leader", participation: p)
      end
    end

    before do
      Fabricate(:"Event::Course::Role::Participant", participation: participation)
    end

    it "only includes participants when filtered to participants" do
      get edit_group_event_bulk_answers_path(group, event,
        filters: {participant_type: "participants"})

      expect(response.body).to include(participant.full_name)
      expect(response.body).not_to include(teamer_participation.participant.full_name)
    end

    it "only includes teamers when filtered to teamers" do
      get edit_group_event_bulk_answers_path(group, event, filters: {participant_type: "teamers"})

      expect(response.body).to include(teamer_participation.participant.full_name)
      expect(response.body).not_to include(participant.full_name)
    end

    it "includes everyone when no filter is given" do
      get edit_group_event_bulk_answers_path(group, event)

      expect(response.body).to include(participant.full_name)
      expect(response.body).to include(teamer_participation.participant.full_name)
    end

    context "with a custom role label" do
      let!(:labeled_participation) do
        Fabricate(:event_participation, event: event, active: true).tap do |p|
          Fabricate(:"Event::Role::Leader", participation: p, label: "Küche")
        end
      end

      it "only includes participations with a matching role label" do
        get edit_group_event_bulk_answers_path(group, event, filters: {participant_type: "Küche"})

        expect(response.body).to include(labeled_participation.participant.full_name)
        expect(response.body).not_to include(participant.full_name)
        expect(response.body).not_to include(teamer_participation.participant.full_name)
      end

      it "includes everyone when the participant_type does not match any role label" do
        get edit_group_event_bulk_answers_path(group, event,
          filters: {participant_type: "unknown"})

        expect(response.body).to include(participant.full_name)
        expect(response.body).to include(teamer_participation.participant.full_name)
        expect(response.body).to include(labeled_participation.participant.full_name)
      end
    end
  end

  describe "PATCH #update" do
    it "updates the text answer and redirects" do
      patch group_event_bulk_answers_path(group, event),
        params: {answers: {answer.id.to_s => {answer: "Keine"}}}
      expect(answer.reload.answer).to eq("Keine")
      expect(response).to redirect_to(edit_group_event_bulk_answers_path(group, event))
    end

    it "handles missing answers param gracefully" do
      patch group_event_bulk_answers_path(group, event)
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
