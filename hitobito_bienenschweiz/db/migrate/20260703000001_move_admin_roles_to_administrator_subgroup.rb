# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class MoveAdminRolesToAdministratorSubgroup < ActiveRecord::Migration[7.1]
  def up
    migrate_roles(
      "Group::Kantonalverband::AdminKanton",
      "Group::KantonalverbandAdministrator::AdminKanton",
      "Group::KantonalverbandAdministrator"
    )
    migrate_roles(
      "Group::Sektion::AdminSektion",
      "Group::SektionAdministrator::AdminSektion",
      "Group::SektionAdministrator"
    )
  end

  def down
    unmigrate_roles(
      "Group::KantonalverbandAdministrator::AdminKanton",
      "Group::Kantonalverband::AdminKanton",
      "Group::KantonalverbandAdministrator"
    )
    unmigrate_roles(
      "Group::SektionAdministrator::AdminSektion",
      "Group::Sektion::AdminSektion",
      "Group::SektionAdministrator"
    )
  end

  private

  def migrate_roles(old_type, new_type, admin_group_type)
    # Update roles where the admin sub-group already exists — pure SQL, no role
    # objects instantiated (avoids constantize error for the removed STI class).
    execute(<<~SQL)
      UPDATE roles
      SET type = #{connection.quote(new_type)},
          group_id = (SELECT id FROM groups
                      WHERE type = #{connection.quote(admin_group_type)}
                        AND parent_id = roles.group_id LIMIT 1)
      WHERE type = #{connection.quote(old_type)}
        AND EXISTS (SELECT 1 FROM groups
                    WHERE type = #{connection.quote(admin_group_type)}
                      AND parent_id = roles.group_id)
    SQL

    # For any remaining roles (no admin sub-group exists yet), create it first.
    connection.select_all(
      "SELECT id, group_id FROM roles WHERE type = #{connection.quote(old_type)}"
    ).each do |row|
      admin_group = find_or_create_admin_group(row["group_id"].to_i, admin_group_type)
      execute(
        "UPDATE roles SET type = #{connection.quote(new_type)}, " \
        "group_id = #{admin_group.id} WHERE id = #{row["id"]}"
      )
    end

    # Update primary_group_id for people whose primary group was the layer group
    # that the role just moved away from.
    execute(<<~SQL)
      UPDATE people
      SET primary_group_id = roles.group_id
      FROM roles
      JOIN groups ON groups.id = roles.group_id
      WHERE roles.type = #{connection.quote(new_type)}
        AND roles.person_id = people.id
        AND people.primary_group_id = groups.parent_id
    SQL
  end

  def unmigrate_roles(current_type, old_type, admin_group_type)
    execute(<<~SQL)
      UPDATE roles
      SET type = #{connection.quote(old_type)},
          group_id = (SELECT parent_id FROM groups WHERE id = roles.group_id)
      WHERE type = #{connection.quote(current_type)}
    SQL

    # Reverse the primary_group_id update: move it back from the admin sub-group
    # to the layer group that now holds the role again.
    execute(<<~SQL)
      UPDATE people
      SET primary_group_id = roles.group_id
      FROM roles
      JOIN groups admin ON admin.parent_id = roles.group_id
        AND admin.type = #{connection.quote(admin_group_type)}
      WHERE roles.type = #{connection.quote(old_type)}
        AND roles.person_id = people.id
        AND people.primary_group_id = admin.id
    SQL
  end

  def find_or_create_admin_group(parent_id, admin_group_type)
    Group.find_by(type: admin_group_type, parent_id: parent_id) ||
      Group.find(parent_id).children.create!(
        type: admin_group_type,
        name: "Administrator",
        layer_group_id: Group.where(id: parent_id).pick(:layer_group_id)
      )
  end
end
