# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class FeedbackQuestion < ApplicationRecord
  include I18nEnums

  has_many :feedback_answers, dependent: :destroy

  i18n_enum :kind, %w[rating yes_no text], queries: true

  validates :text, presence: true

  scope :list, -> { order(:position) }

  def to_s
    text
  end

  # Validates the given FeedbackAnswer against this question's kind.
  # Called from FeedbackAnswer#validate.
  def validate_answer(answer) # rubocop:disable Metrics/CyclomaticComplexity
    case kind
    when "rating" then validate_rating(answer)
    when "yes_no" then answer.errors.add(:yes_no, :blank) if answer.yes_no.nil? && required?
    when "text" then answer.errors.add(:text, :blank) if answer.text.blank? && required?
    end
  end

  private

  def validate_rating(answer)
    if answer.rating.nil?
      answer.errors.add(:rating, :blank) if required?
    elsif !(1..5).cover?(answer.rating)
      answer.errors.add(:rating, :not_in_range)
    end
  end
end
