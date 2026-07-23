# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateFeedbackAnswers < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_answers do |t|
      t.references :feedback_invitation, null: false, foreign_key: true
      t.references :feedback_question, null: false, foreign_key: true
      t.integer :rating
      t.boolean :yes_no
      t.text :text

      t.timestamps

      t.index [:feedback_invitation_id, :feedback_question_id], unique: true,
        name: "index_feedback_answers_on_invitation_and_question"
    end
  end
end
