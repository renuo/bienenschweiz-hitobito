# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Roles start and end by date without triggering any callbacks, so the daily job
# also keeps the Spesen Sektion in sync with the currently active roles.
module Bienenschweiz::UpdateAfterRoleChangeJob
  private

  def perform_internal
    super
    update_spesen_sektionen
  end

  def update_spesen_sektionen
    eligible = ::Role.where(type: Bienenschweiz::Person::SPESEN_ROLES).select(:person_id)
    ::Person.where(id: eligible).or(::Person.where.not(spesen_sektion_id: nil))
      .find_each(&:sync_spesen_sektion!)
  end
end
