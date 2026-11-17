# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class RenameKaderToFachpersonen < ActiveRecord::Migration[8.0]
  def up
    rename_types(from: "Group::Kader", to: "Group::Fachpersonen")
    rename_groups(from: "Kader", to: "Fachpersonen")
  end

  def down
    rename_groups(from: "Fachpersonen", to: "Kader")
    rename_types(from: "Group::Fachpersonen", to: "Group::Kader")
  end

  private

  # Renames the group type and the role types nested in it (Group::Kader::FachpersonBildung, ...)
  # wherever they are stored.
  def rename_types(from:, to:)
    rename_column_values(:groups, :type, from, to)
    rename_column_values(:roles, :type, from, to)
    rename_column_values(:groups, :self_registration_role_type, from, to)
    rename_column_values(:related_role_types, :role_type, from, to)
    rename_column_values(:event_question_visibilities, :role_type, from, to)
    rename_column_values(:person_add_requests, :role_type, from, to)
    rename_column_values(:role_type_orders, :name, from, to)
    rename_column_values(:groups_filters, :group_type, from, to)
    rename_column_values(:people_filters, :group_type, from, to)
    rename_in_filter_chains(:people_filters, from, to)
    rename_in_filter_chains(:mailing_lists, from, to)
  end

  def rename_column_values(table, column, from, to)
    execute(<<~SQL)
      UPDATE #{table}
      SET #{column} = #{quote(to)} || SUBSTRING(#{column} FROM #{from.length + 1})
      WHERE #{column} = #{quote(from)} OR #{column} LIKE #{quote("#{from}::%")}
    SQL
  end

  def rename_in_filter_chains(table, from, to)
    execute(<<~SQL)
      UPDATE #{table}
      SET filter_chain = REPLACE(filter_chain, #{quote("#{from}::")}, #{quote("#{to}::")})
      WHERE filter_chain LIKE #{quote("%#{from}::%")}
    SQL
  end

  # Groups that still carry the default name follow the new label. Manually renamed ones
  # are left untouched.
  def rename_groups(from:, to:)
    execute(<<~SQL)
      UPDATE groups SET name = #{quote(to)}
      WHERE type = 'Group::Fachpersonen' AND name = #{quote(from)}
    SQL
  end
end
