# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::Event::Participation
  extend ActiveSupport::Concern

  # Overrides core so registering as a leader/participant does not build answer
  # stubs for questions marked relevant only for the other role.
  def init_answers
    answers.tap do |list|
      event.questions.list.each do |question|
        next unless question.relevant_for?(self)
        next if list.find { |answer| answer.question_id == question.id }

        list << question.answers.new(question: question)
      end
    end
  end
end
