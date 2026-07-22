# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateFeedbackQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_questions do |t|
      t.string :kind, null: false
      t.string :text, null: false
      t.integer :position, null: false, default: 0
      t.boolean :required, null: false, default: true

      t.timestamps
    end
  end
end
