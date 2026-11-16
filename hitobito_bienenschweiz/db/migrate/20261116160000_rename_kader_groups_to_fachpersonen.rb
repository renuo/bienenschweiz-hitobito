# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class RenameKaderGroupsToFachpersonen < ActiveRecord::Migration[7.1]
  # Group::Kader is now labelled Fachpersonen. Rename the existing groups that still
  # carry the default name, but leave manually renamed ones untouched.
  def up
    rename_groups(from: "Kader", to: "Fachpersonen")
  end

  def down
    rename_groups(from: "Fachpersonen", to: "Kader")
  end

  private

  def rename_groups(from:, to:)
    execute <<~SQL
      UPDATE groups SET name = #{quote(to)}
      WHERE type = 'Group::Kader' AND name = #{quote(from)}
    SQL
  end
end
