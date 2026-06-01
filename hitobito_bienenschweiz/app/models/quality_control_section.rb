# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class QualityControlSection < ApplicationRecord
  has_many :quality_control_questions, dependent: :destroy

  validates :title, :number, :version, presence: true

  VERSION_1_CUTOFF = 2020
  VERSION_2_CUTOFF = Time.zone.local(2024, 6, 1)

  # Versioning note:
  # Currently, the version is determined by the date a quality control was created.
  # This works, as long as the questions have a similar meaning/asking for the same thing.
  # If the questions itself change their meaning, new questions are added or questions are removed,
  # the versioning needs to be reflected also in
  # the mobile app since the app can submit quality controls that were conducted in the past.
  # (e.g. edge case: control on 30-05, new questions on 01-06, submitted on 02-06)
  # This is not implemented yet. If this will be necessary,
  # the Api::Mobile::V1::QualityControlQuestionsController
  # needs to be adjusted to return the questions applicable for a specific control date
  scope :for_current_version, lambda {
    where(version: version)
  }

  scope :for_version, lambda { |date|
    where(version: version(date))
  }

  def self.version(date = Time.zone.now)
    return 1 if date.year < VERSION_1_CUTOFF
    return 2 if date < VERSION_2_CUTOFF

    3
  end
end
