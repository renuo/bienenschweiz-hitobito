class AddQualityControlTables < ActiveRecord::Migration[8.0]
  def change
    create_table "quality_control_answers", id: :integer, charset: "utf8mb3", force: :cascade do |t|
      t.date "deadline_at"
      t.text "notes"
      t.integer "quality_control_question_id", null: false
      t.integer "qcontrol_id", null: false
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
      t.string "fulfilled", default: "passed", null: false
      t.index ["qcontrol_id"], name: "index_quality_control_answers_on_qcontrol_id"
      t.index ["quality_control_question_id"], name: "index_quality_control_answers_on_quality_control_question_id"
    end

    create_table "quality_control_questions", id: :integer, charset: "utf8mb3", force: :cascade do |t|
      t.integer "number", null: false
      t.string "title", null: false
      t.text "description"
      t.integer "quality_control_section_id", null: false
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
      t.text "inspection_notes"
      t.index ["quality_control_section_id"], name: "index_quality_control_questions_on_quality_control_section_id"
    end

    create_table "quality_control_sections", id: :integer, charset: "utf8mb3", force: :cascade do |t|
      t.string "title", null: false
      t.integer "number", null: false
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
      t.integer "version", default: 1, null: false
    end
  end
end
