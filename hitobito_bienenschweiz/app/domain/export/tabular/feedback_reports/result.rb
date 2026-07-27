# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Export::Tabular::FeedbackReports
  # Exports the responses of every FeedbackRound in the given (filtered) scope:
  # same shape as Export::Tabular::FeedbackRounds::Result (one row per invited
  # participant, one column per FeedbackQuestion), plus a course number column
  # since rows here span multiple courses.
  class Result < Export::Tabular::Base
    self.row_class = ResultRow
    self.model_class = FeedbackInvitation
    self.styled_attrs = {datetime: [:submitted_at]}

    def initialize(rounds, ability = nil)
      super(
        FeedbackInvitation.where(feedback_round: rounds).includes(
          :feedback_answers,
          participation: :participant,
          feedback_round: {event: :groups}
        ),
        ability
      )
    end

    def sheet_name
      I18n.t("feedback_reports.title")
    end

    def build_attribute_labels
      labels = {
        course_number: Event::Course.human_attribute_name(:number),
        person: "Person",
        submitted_at: "Eingereicht am"
      }
      questions.each { |question| labels[:"question_#{question.id}"] = question.text }
      labels
    end

    private

    def questions
      FeedbackQuestion.list
    end
  end
end
