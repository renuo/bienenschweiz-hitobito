# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class MergeBienenZeitungAboRoles < ActiveRecord::Migration[7.1]
  OLD_TYPES = %w[
    Group::BienenZeitung::Abo
    Group::BienenZeitung::AboEuro
    Group::BienenZeitung::GratisAbo
    Group::BienenZeitung::OnlineAbo
    Group::BienenZeitung::GeschenkAbo
    Group::BienenZeitung::BuchhaendlerAbo
  ].freeze

  NEW_TYPE = "Group::BienenZeitung::Abonnent"

  def up
    rename_roles
    dedupe_roles
    rename_role_type_references
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_roles
    execute(<<~SQL)
      UPDATE roles SET type = #{quoted_new_type}
      WHERE type IN (#{quoted_old_types})
    SQL
  end

  def dedupe_roles
    execute(<<~SQL)
      DELETE FROM roles WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY person_id, group_id, start_on, end_on, archived_at
            ORDER BY id
          ) AS row_number
          FROM roles WHERE type = #{quoted_new_type}
        ) duplicates WHERE duplicates.row_number > 1
      )
    SQL
  end

  def rename_role_type_references
    dedupe_event_question_visibilities

    %w[related_role_types event_question_visibilities person_add_requests].each do |table|
      execute(<<~SQL)
        UPDATE #{table} SET role_type = #{quoted_new_type}
        WHERE role_type IN (#{quoted_old_types})
      SQL
    end
    execute(<<~SQL)
      UPDATE groups SET self_registration_role_type = #{quoted_new_type}
      WHERE self_registration_role_type IN (#{quoted_old_types})
    SQL
    execute("DELETE FROM role_type_orders WHERE name IN (#{quoted_old_types})")

    dedupe_related_role_types
  end

  def dedupe_related_role_types
    execute(<<~SQL)
      DELETE FROM related_role_types WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY relation_id, relation_type ORDER BY id
          ) AS row_number
          FROM related_role_types WHERE role_type = #{quoted_new_type}
        ) duplicates WHERE duplicates.row_number > 1
      )
    SQL
  end

  def dedupe_event_question_visibilities
    execute(<<~SQL)
      DELETE FROM event_question_visibilities WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY question_id ORDER BY id
          ) AS row_number
          FROM event_question_visibilities WHERE role_type IN (#{quoted_old_types})
        ) duplicates WHERE duplicates.row_number > 1
      )
    SQL
  end

  def quoted_new_type
    connection.quote(NEW_TYPE)
  end

  def quoted_old_types
    OLD_TYPES.map { |type| connection.quote(type) }.join(", ")
  end
end
