# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz::Role
  extend ActiveSupport::Concern

  included do
    after_save :sync_spesen_sektion, if: :spesen_role?
    after_destroy :sync_spesen_sektion, if: :spesen_role?
  end

  private

  def spesen_role?
    Bienenschweiz::Person::SPESEN_ROLES.include?(type)
  end

  def sync_spesen_sektion
    ::Person.find_by(id: person_id)&.sync_spesen_sektion!
  end
end
