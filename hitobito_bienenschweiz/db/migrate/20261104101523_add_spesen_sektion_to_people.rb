# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class AddSpesenSektionToPeople < ActiveRecord::Migration[8.0]
  SPESEN_ROLES = %w[
    Group::Kader::FachpersonBildung
    Group::Kader::FachpersonProdukte
    Group::Kader::FachpersonZuchtVermehrung
  ].freeze

  def up
    add_reference :people, :spesen_sektion, null: true, index: true,
      foreign_key: {to_table: :groups, on_delete: :nullify}

    backfill_spesen_sektion
  end

  def down
    remove_reference :people, :spesen_sektion, foreign_key: {to_table: :groups}
  end

  private

  # Default to the Sektion of the person's first (oldest) active eligible role.
  def backfill_spesen_sektion
    types = SPESEN_ROLES.map { |type| connection.quote(type) }.join(", ")
    execute <<~SQL.squish
      UPDATE people SET spesen_sektion_id = first_roles.sektion_id
      FROM (
        SELECT DISTINCT ON (roles.person_id) roles.person_id, groups.layer_group_id AS sektion_id
        FROM roles
        INNER JOIN groups ON groups.id = roles.group_id
        INNER JOIN groups sektionen ON sektionen.id = groups.layer_group_id
        WHERE roles.type IN (#{types})
          AND sektionen.type = 'Group::Sektion'
          AND sektionen.deleted_at IS NULL
          AND (roles.start_on IS NULL OR roles.start_on <= CURRENT_DATE)
          AND (roles.end_on IS NULL OR roles.end_on >= CURRENT_DATE)
        ORDER BY roles.person_id, roles.id
      ) first_roles
      WHERE people.id = first_roles.person_id
    SQL
  end
end
