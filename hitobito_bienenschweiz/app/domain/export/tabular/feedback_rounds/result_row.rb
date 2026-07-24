# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Export::Tabular::FeedbackRounds
  # Row decorator for a single FeedbackInvitation (one participant),
  # exposing one dynamic column per FeedbackQuestion.
  class ResultRow < Export::Tabular::Row
    dynamic_attributes[/^question_\d+$/] = :question_attribute

    def person
      entry.person.to_s
    end

    def submitted_at
      entry.submitted_at
    end

    private

    def question_attribute(attr)
      question_id = attr.to_s.split("_").last.to_i
      answer = entry.feedback_answers.find { |a| a.feedback_question_id == question_id }
      answer&.value
    end
  end
end
