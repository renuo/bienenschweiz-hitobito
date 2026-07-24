# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe FeedbackRoundsController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:admin) { people(:admin) }
  let(:event) { Fabricate(:course, kind: Fabricate(:event_kind), groups: [sektion]) }
  let(:participant) { Fabricate(:person) }

  before do
    roles(:admin)
    sign_in(admin)
    participation = Fabricate(:event_participation, event:, active: true, participant:)
    Fabricate(Event::Course::Role::Participant.sti_name.to_sym, participation:)
  end

  let!(:round) { Fabricate(:feedback_round, event:) }

  describe "#show" do
    it "renders successfully" do
      get group_event_feedback_round_path(sektion, event, round)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.full_name)
    end

    it "shows the Feedback tab as active, nested under the course" do
      get group_event_feedback_round_path(sektion, event, round)
      expect(response.body).to match(/<li class="active"[^>]*>.*Feedback.*<\/li>/m)
    end
  end

  describe "#index" do
    it "shows the Feedback tab as active" do
      get group_event_feedback_rounds_path(sektion, event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<li class="active"[^>]*>.*Feedback.*<\/li>/m)
    end
  end

  describe "#new" do
    it "shows the Feedback tab as active" do
      get new_group_event_feedback_round_path(sektion, event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<li class="active"[^>]*>.*Feedback.*<\/li>/m)
    end
  end

  describe "#create" do
    it "creates a round and generates invitations" do
      expect {
        post group_event_feedback_rounds_path(sektion, event),
          params: {feedback_round: {kind: "intermediate"}}
      }.to change(FeedbackRound, :count).by(1)

      created = FeedbackRound.last
      expect(created.author).to eq(admin)
      expect(created.feedback_invitations.count).to eq(1)
      expect(response).to redirect_to(group_event_feedback_rounds_path(sektion, event))
    end

    context "when a final round already exists" do
      before { Fabricate(:feedback_round, event:, kind: "final") }

      it "does not create another round" do
        expect {
          post group_event_feedback_rounds_path(sektion, event),
            params: {feedback_round: {kind: "intermediate"}}
        }.not_to change(FeedbackRound, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "as a person without edit permission on the course" do
      let(:reader) { Fabricate(:person) }

      before { sign_in(reader) }

      it "raises access denied" do
        expect {
          post group_event_feedback_rounds_path(sektion, event),
            params: {feedback_round: {kind: "intermediate"}}
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "#report" do
    let(:rating_question) { Fabricate(:feedback_question, kind: "rating") }

    before do
      invitation = round.feedback_invitations.first
      invitation.update!(submitted_at: Time.zone.now)
      Fabricate(:feedback_answer, feedback_question: rating_question,
        feedback_invitation: invitation, rating: 5)
    end

    it "renders the report with the course's data" do
      get report_group_event_feedback_round_path(sektion, event, round)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.name)
      expect(response.body).to include(rating_question.text)
    end

    context "as a person without edit permission on the course" do
      let(:reader) { Fabricate(:person) }

      before { sign_in(reader) }

      it "raises access denied" do
        expect {
          get report_group_event_feedback_round_path(sektion, event, round)
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "#destroy" do
    it "destroys the round and its invitations" do
      expect {
        delete group_event_feedback_round_path(sektion, event, round)
      }.to change(FeedbackRound, :count).by(-1)

      expect(response).to redirect_to(group_event_feedback_rounds_path(sektion, event))
    end
  end
end
