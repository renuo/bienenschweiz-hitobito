class QualityControlAnswer < ApplicationRecord
  belongs_to :quality_control_question, optional: false
  belongs_to :qcontrol, inverse_of: :quality_control_answers, optional: false

  enum :fulfilled, { not_passed: 'not_passed', passed: 'passed', partially_passed: 'partially_passed' }
  scope :of_section, lambda { |section|
    joins(:quality_control_question).where(quality_control_questions: { quality_control_section_id: section.id })
  }

  validates :fulfilled, presence: true
  validates :deadline_at, presence: true, if: :partially_passed?
end
