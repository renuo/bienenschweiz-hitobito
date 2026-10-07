# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class AddGeocodingToSiegelimkerProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :siegelimker_profiles, :manual_coordinates, :boolean, null: false, default: false
    add_column :siegelimker_profiles, :geocoded_address, :string
  end
end
