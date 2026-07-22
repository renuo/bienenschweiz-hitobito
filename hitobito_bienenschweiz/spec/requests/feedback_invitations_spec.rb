# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe FeedbackInvitationsController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:event) { Fabricate(:course, kind: Fabricate(:event_kind), groups: [sektion]) }
  let(:participant) { Fabricate(:person) }
  let(:round) { Fabricate(:feedback_round, event:) }
  let!(:invitation) {
    participation = Fabricate(:event_participation, event:, active: true, participant:)
    Fabricate(:feedback_invitation, feedback_round: round, participation:)
  }

  describe "#edit" do
    it "renders the feedback form without signing in" do
      get edit_feedback_invitation_path(invitation.token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.name)
    end

    context "when already submitted" do
      before { invitation.update!(submitted_at: Time.zone.now) }

      it "renders the thank you message" do
        get edit_feedback_invitation_path(invitation.token)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the round is closed" do
      before { round.update!(closes_at: 1.day.ago) }

      it "renders the closed message" do
        get edit_feedback_invitation_path(invitation.token)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "#update" do
    let!(:required_question) { Fabricate(:feedback_question, kind: "rating", required: true) }

    let(:params) do
      answers = FeedbackQuestion.list.index_with do |question|
        case question.kind
        when "rating" then {rating: 5}
        when "yes_no" then {yes_no: true}
        when "text" then {text: "Alles bestens"}
        end
      end
      {feedback_answers: answers.transform_keys { |q| q.id.to_s }}
    end

    it "saves answers and marks the invitation submitted" do
      patch feedback_invitation_path(invitation.token), params: params
      expect(response).to redirect_to(edit_feedback_invitation_path(invitation.token))
      expect(invitation.reload).to be_submitted
    end

    context "with missing answers to required questions" do
      let(:params) { {feedback_answers: {}} }

      it "does not mark the invitation submitted and re-renders the form" do
        patch feedback_invitation_path(invitation.token), params: params
        expect(response).to have_http_status(:unprocessable_content)
        expect(invitation.reload).not_to be_submitted
      end
    end

    context "when already submitted" do
      before { invitation.update!(submitted_at: Time.zone.now) }

      it "redirects without changing the answers" do
        expect {
          patch feedback_invitation_path(invitation.token), params: params
        }.not_to change { invitation.feedback_answers.count }

        expect(response).to redirect_to(edit_feedback_invitation_path(invitation.token))
      end
    end

    context "when the round is closed" do
      before { round.update!(closes_at: 1.day.ago) }

      it "redirects without changing the answers" do
        expect {
          patch feedback_invitation_path(invitation.token), params: params
        }.not_to change { invitation.feedback_answers.count }

        expect(response).to redirect_to(edit_feedback_invitation_path(invitation.token))
      end
    end
  end
end
