# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::Event::ParticipationDecorator
  # Overrides core so a required question that isn't relevant for this
  # participation's role (e.g. a leaders-only question for a participant) is
  # not flagged as missing information.
  def incomplete_label
    if answers.any? { |answer| incomplete_answer?(answer) }
      content_tag(:div, h.t(".incomplete"), class: "text-warning")
    end
  end

  private

  def incomplete_answer?(answer)
    answer.question&.required? && answer.answer.blank? && answer.question.relevant_for?(model)
  end
end
