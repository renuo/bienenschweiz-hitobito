# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class AddSupervisions < ActiveRecord::Migration[8.0]
  def change
    create_table "supervisions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
      t.date "check_date", null: false
      t.integer "supervisor_id"
      t.integer "author_id", null: false
      t.string "result", null: false
      t.string "kind", null: false
      t.integer "course_type_id", null: false
      t.integer "person_id", null: false
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
      t.index ["author_id"], name: "index_supervisions_on_author_id"
      t.index ["course_type_id"], name: "index_supervisions_on_course_type_id"
      t.index ["person_id"], name: "index_supervisions_on_person_id"
      t.index ["supervisor_id"], name: "index_supervisions_on_supervisor_id"
    end
  end
end
