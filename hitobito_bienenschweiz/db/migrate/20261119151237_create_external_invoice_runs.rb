# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateExternalInvoiceRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :external_invoice_runs do |t|
      t.string :state, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :due_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.timestamps
    end

    add_reference :hitobito_log_entries, :external_invoice_run, null: true, index: true
  end
end
