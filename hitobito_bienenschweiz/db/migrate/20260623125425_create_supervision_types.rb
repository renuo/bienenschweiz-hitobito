# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class CreateSupervisionTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :supervision_types do |t|
      t.string :name, null: false

      t.timestamps
      t.index :name, unique: true
    end

    add_column :supervisions, :supervision_type_id, :integer
    remove_column :supervisions, :course_type_id
  end
end
