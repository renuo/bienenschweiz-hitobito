# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateMagazineSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :magazine_subscriptions do |t|
      t.references :person, null: false, foreign_key: {to_table: :people}
      t.date :start_date, null: false
      t.date :end_date
      t.string :subscription_type, null: false
      t.integer :amount, null: false, default: 1
      t.text :cancellation_reason

      t.timestamps
    end
  end
end
