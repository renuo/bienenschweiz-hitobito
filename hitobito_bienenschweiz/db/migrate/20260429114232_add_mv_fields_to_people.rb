# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class AddMvFieldsToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :salutation, :string
    add_column :people, :hive_count, :string
    add_column :people, :honey_yield, :string
    add_column :people, :export_to_website, :boolean, default: true, null: false
    add_column :people, :num_ad_boards, :integer
  end
end
