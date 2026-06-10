# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class Supervision < ApplicationRecord
  include I18nEnums

  # TODO: documents
  # mount_uploader :document, AssetUploader

  belongs_to :person
  belongs_to :author, class_name: "Person"
  belongs_to :supervisor, class_name: "Person", optional: true
  belongs_to :course_type, class_name: "Event::Kind"

  validates :check_date, :kind, :result, presence: true
  validate :assert_supervisor_role, if: :supervisor_id

  # Documents which results belong to which kind. Not validated: the old
  # app only enforced this in the UI and legacy data may violate it.
  KINDS = {
    supervision: %w[fulfilled partially_fulfilled not_fulfilled],
    feedback: %w[good enough not_enough no_statement]
  }.freeze

  i18n_enum :kind, KINDS.keys.map(&:to_s), queries: true
  i18n_enum :result, KINDS.values.flatten, queries: true

  private

  def assert_supervisor_role
    unless Person.supervisors.exists?(id: supervisor_id)
      errors.add(:supervisor_id, :no_supervisor_role)
    end
  end
end
