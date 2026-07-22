# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Public, unauthenticated form used by course participants to submit feedback.
# The invitation token is the sole credential, following the same pattern as
# Calendars::FeedsController / People::Membership::VerifyController.
class FeedbackInvitationsController < ApplicationController
  skip_authorization_check
  skip_before_action :authenticate_person!

  before_action :load_invitation

  def edit
    @feedback_questions = FeedbackQuestion.list
    @answers = build_answers unless @invitation.submitted?
  end

  def update
    if @invitation.submitted? || @invitation.closed?
      redirect_to edit_feedback_invitation_path(@invitation.token)
      return
    end

    @feedback_questions = FeedbackQuestion.list
    @answers = build_answers

    if @answers.all?(&:valid?)
      FeedbackAnswer.transaction do
        @answers.each(&:save!)
        @invitation.update!(submitted_at: Time.zone.now)
      end
      redirect_to edit_feedback_invitation_path(@invitation.token)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_invitation
    @invitation = FeedbackInvitation.find_by!(token: params[:token])
    @event = @invitation.event
  end

  def build_answers
    @feedback_questions.map do |question|
      answer = @invitation.feedback_answers.find_or_initialize_by(feedback_question: question)
      answer.assign_attributes(answer_params(question))
      answer
    end
  end

  def answer_params(question)
    params.fetch(:feedback_answers, {}).fetch(question.id.to_s, {})
      .permit(:rating, :yes_no, :text)
  end
end
