# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class CreateMitarbeiterGroups < ActiveRecord::Migration[7.1]
  # Group::Mitarbeiter is a default child of Group::Dachverband, but default children
  # are only created together with a new Dachverband, so add it to existing ones.
  def up
    Group.where(type: "Group::Dachverband").find_each do |dachverband|
      next if Group.exists?(type: "Group::Mitarbeiter", parent_id: dachverband.id)

      dachverband.children.create!(
        type: "Group::Mitarbeiter",
        name: "Mitarbeiter/in",
        layer_group_id: dachverband.layer_group_id
      )
    end
  end

  def down
    # The groups may hold roles by now; remove them manually if really needed.
    raise ActiveRecord::IrreversibleMigration
  end
end
