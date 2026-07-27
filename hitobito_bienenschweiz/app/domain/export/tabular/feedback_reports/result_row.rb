# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Export::Tabular::FeedbackReports
  # Row decorator for a single FeedbackInvitation across many courses/rounds.
  # Reuses FeedbackRounds::ResultRow's person/submitted_at/question columns
  # and adds the course number, since a single-round export doesn't need one.
  class ResultRow < Export::Tabular::FeedbackRounds::ResultRow
    def course_number
      entry.feedback_round.event.number
    end
  end
end
