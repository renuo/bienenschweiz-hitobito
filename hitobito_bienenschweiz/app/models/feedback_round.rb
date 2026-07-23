# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class FeedbackRound < ApplicationRecord
  include I18nEnums

  belongs_to :event
  belongs_to :author, class_name: "Person"
  has_many :feedback_invitations, dependent: :destroy

  i18n_enum :kind, %w[intermediate final], queries: true

  validates :kind, presence: true
  validates :author, presence: true
  validate :assert_no_round_after_final, on: :create

  after_create :generate_invitations

  def response_count
    feedback_invitations.where.not(submitted_at: nil).count
  end

  def to_s
    return kind_label if created_at.nil?

    "#{kind_label} (#{I18n.l(created_at.to_date)})"
  end

  private

  def assert_no_round_after_final
    return if event.nil?

    if event.feedback_rounds.where(kind: "final").exists?
      errors.add(:base, :final_round_exists)
    end
  end

  def generate_invitations
    participant_types = event.class.participant_types.map(&:sti_name)
    event.participations.active
      .joins(:roles).where(event_roles: {type: participant_types})
      .distinct.find_each do |participation|
      feedback_invitations.create!(participation:)
    end
  end
end
