# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class FeedbackInvitation < ApplicationRecord
  belongs_to :feedback_round
  belongs_to :participation, class_name: "Event::Participation"
  belongs_to :event
  has_many :feedback_answers, dependent: :destroy

  validates :participation_id, uniqueness: {scope: :feedback_round_id}

  before_validation :set_event, on: :create
  before_create :generate_token

  def person
    participation.participant
  end

  def submitted?
    submitted_at.present?
  end

  def closed?
    feedback_round.closes_at.present? && feedback_round.closes_at.past?
  end

  private

  def set_event
    self.event ||= feedback_round&.event
  end

  def generate_token
    self.token = loop do
      candidate = SecureRandom.urlsafe_base64
      break candidate unless self.class.exists?(token: candidate)
    end
  end
end
