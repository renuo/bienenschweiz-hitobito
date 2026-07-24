# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

# Aggregates the FeedbackAnswers collected for a given set of FeedbackRounds
# (a single round, or every final round of many courses) into the data a
# Feedback::Report view renders as charts and grouped text answers.
class Feedback::Report
  def initialize(rounds)
    @rounds = rounds
  end

  def questions
    @questions ||= FeedbackQuestion.list
  end

  def courses
    @courses ||= Event::Course.where(id: @rounds.select(:event_id)).distinct.to_a
  end

  def invitation_count
    @invitation_count ||= invitations.count
  end

  def response_count
    @response_count ||= submitted_invitations.count
  end

  def rating_counts(question)
    counts = answers_for(question).group(:rating).count
    (1..5).index_with { |value| counts[value].to_i }
  end

  def yes_no_counts(question)
    counts = answers_for(question).group(:yes_no).count
    {true => counts[true].to_i, false => counts[false].to_i}
  end

  def text_answers(question)
    answers_for(question)
      .where.not(text: [nil, ""])
      .joins(:feedback_invitation)
      .order("feedback_invitations.submitted_at")
      .pluck(:text)
  end

  private

  def invitations
    @invitations ||= FeedbackInvitation.where(feedback_round: @rounds)
  end

  def submitted_invitations
    @submitted_invitations ||= invitations.where.not(submitted_at: nil)
  end

  def answers_for(question)
    FeedbackAnswer.where(feedback_question: question, feedback_invitation: submitted_invitations)
  end
end
