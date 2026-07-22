# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Export::Tabular::FeedbackRounds
  # Exports the responses of a single FeedbackRound: one row per invited
  # participant, one column per FeedbackQuestion.
  class Result < Export::Tabular::Base
    self.row_class = ResultRow
    self.model_class = FeedbackInvitation
    self.styled_attrs = {datetime: [:submitted_at]}

    def initialize(feedback_round, ability = nil)
      @feedback_round = feedback_round
      super(
        feedback_round.feedback_invitations.includes(:feedback_answers,
          participation: :participant),
        ability
      )
    end

    def sheet_name
      @feedback_round.to_s
    end

    def build_attribute_labels
      labels = {person: "Person", submitted_at: "Eingereicht am"}
      questions.each { |question| labels[:"question_#{question.id}"] = question.text }
      labels
    end

    private

    def questions
      FeedbackQuestion.list
    end
  end
end
