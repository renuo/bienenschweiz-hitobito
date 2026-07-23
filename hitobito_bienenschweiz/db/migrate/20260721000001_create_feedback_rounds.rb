# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateFeedbackRounds < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_rounds do |t|
      t.references :event, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :author_id, null: false
      t.datetime :closes_at

      t.timestamps

      t.index [:event_id, :kind], unique: true, where: "kind = 'final'",
        name: "index_feedback_rounds_on_event_id_and_final_kind"
    end
  end
end
