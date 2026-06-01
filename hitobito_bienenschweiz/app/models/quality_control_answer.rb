# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class QualityControlAnswer < ApplicationRecord
  belongs_to :quality_control_question, optional: false
  belongs_to :qcontrol, inverse_of: :quality_control_answers, optional: false

  enum :fulfilled,
    {not_passed: "not_passed", passed: "passed", partially_passed: "partially_passed"}
  scope :of_section, lambda { |section|
    joins(:quality_control_question).where(
      quality_control_questions: {quality_control_section_id: section.id}
    )
  }

  validates :fulfilled, presence: true
  validates :deadline_at, presence: true, if: :partially_passed?
end
