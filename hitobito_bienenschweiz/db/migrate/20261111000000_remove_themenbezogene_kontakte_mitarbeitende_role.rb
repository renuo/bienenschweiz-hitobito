# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class RemoveThemenbezogeneKontakteMitarbeitendeRole < ActiveRecord::Migration[8.0]
  def up
    role_type = connection.quote("Group::ThemenbezogeneKontakte::Mitarbeitende")

    delete_pass_grants_without_remaining_roles(role_type)
    %w[related_role_types event_question_visibilities person_add_requests].each do |table|
      execute("DELETE FROM #{table} WHERE role_type = #{role_type}")
    end

    execute(<<~SQL)
      UPDATE groups SET self_registration_role_type = NULL, main_self_registration_group = FALSE
      WHERE self_registration_role_type = #{role_type}
    SQL
    execute("DELETE FROM role_type_orders WHERE name = #{role_type}")
    execute("DELETE FROM roles WHERE type = #{role_type}")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def delete_pass_grants_without_remaining_roles(role_type)
    execute(<<~SQL)
      DELETE FROM pass_grants
      WHERE id IN (
        SELECT relation_id FROM related_role_types
        WHERE relation_type = 'PassGrant'
        GROUP BY relation_id
        HAVING bool_and(role_type = #{role_type})
      )
    SQL
  end
end
