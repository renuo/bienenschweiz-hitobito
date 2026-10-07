# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Updates the coordinates of a website profile after the address of its person changed.
class SiegelimkerProfileGeocodeJob < BaseJob
  self.parameters = [:profile_id]

  def initialize(profile_id)
    super()
    @profile_id = profile_id
  end

  def perform
    profile = SiegelimkerProfile.find_by(id: @profile_id)
    # geocoding happens in a before_save callback
    profile&.save(validate: false)
  end
end
