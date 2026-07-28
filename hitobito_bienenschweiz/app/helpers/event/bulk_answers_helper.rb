# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Event::BulkAnswersHelper
  # Appends the translated role(s) in parentheses for anyone whose role isn't
  # a basic participant, so admins can tell teamers/leaders apart in the list.
  # Suppressed on participants-only questions: someone can hold both a leader
  # and a plain participant role, and there they're answering as a
  # participant, so the leader role would be misleading. On leaders-only and
  # mixed (everyone) questions the role is useful, so it's kept.
  def participation_label(participation, question)
    return participation.to_s if question.relevance == Bienenschweiz::Event::Question::PARTICIPANTS

    extra_roles = participation.roles.reject { |role| role.class.participant? }
    return participation.to_s if extra_roles.empty?

    "#{participation} (#{extra_roles.map(&:to_s).join(", ")})"
  end
end
