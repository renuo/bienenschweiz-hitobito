# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class FeedbackAnswer < ApplicationRecord
  belongs_to :feedback_question
  belongs_to :feedback_invitation

  validates :feedback_question_id, uniqueness: {scope: :feedback_invitation_id}
  validate :validate_with_question

  def value
    public_send(feedback_question.kind)
  end

  private

  def validate_with_question
    feedback_question.validate_answer(self)
  end
end
