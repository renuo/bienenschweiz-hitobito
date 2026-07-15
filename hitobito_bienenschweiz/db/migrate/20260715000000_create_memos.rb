# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateMemos < ActiveRecord::Migration[8.0]
  def change
    create_table "memos", id: :integer, charset: "utf8mb3", force: :cascade do |t|
      t.string "title", null: false
      t.text "body", null: false
      t.integer "person_id", null: false
      t.integer "author_id"
      t.string "author_name"
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
      t.index ["person_id"], name: "index_memos_on_person_id"
      t.index ["author_id"], name: "index_memos_on_author_id"
    end
  end
end
