# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateExternalInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :abacus_subject_key, :integer

    create_table :external_invoices do |t|
      t.belongs_to :person, null: false, index: true
      t.string :type, null: false
      t.string :state, null: false, default: "draft"
      t.date :period_start
      t.date :issued_at
      t.date :sent_at
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0.0
      t.belongs_to :link, polymorphic: true, index: false, null: true
      t.integer :abacus_sales_order_key
      t.timestamps
    end

    add_index :external_invoices, [:link_type, :link_id, :period_start], unique: true
  end
end
