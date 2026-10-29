# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class RemoveSiegelimkerSinceFromSiegelimkerProfiles < ActiveRecord::Migration[8.0]
  def change
    remove_column :siegelimker_profiles, :siegelimker_since, :integer
  end
end
