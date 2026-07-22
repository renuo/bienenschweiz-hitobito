# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateFeedbackInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_invitations do |t|
      t.references :feedback_round, null: false, foreign_key: true
      t.references :participation, null: false, foreign_key: {to_table: :event_participations}
      t.references :event, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :submitted_at

      t.timestamps

      t.index :token, unique: true
      t.index [:feedback_round_id, :participation_id], unique: true,
        name: "index_feedback_invitations_on_round_and_participation"
    end
  end
end
