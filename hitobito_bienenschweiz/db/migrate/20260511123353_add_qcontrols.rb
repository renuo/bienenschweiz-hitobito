class AddQcontrols < ActiveRecord::Migration[8.0]
  def change
    create_table "qcontrols", id: :integer, charset: "utf8mb3", force: :cascade do |t|
      t.integer "person_id"
      t.integer "author_id"
      t.integer "group_id", null: false
      t.string "title"
      t.string "document"
      t.string "content_type"
      t.integer "file_size"
      t.date "control_date"
      t.datetime "created_at", precision: nil
      t.datetime "updated_at", precision: nil
      t.string "author_name"
      t.string "control_state"
      t.string "no_control_reason", default: ""
      t.string "other_reason_for_no_control", default: "", null: false
      t.string "business_handover_to", default: "", null: false
      t.integer "inspector_id"
      t.string "fee_creation_state", default: "fee_not_created"
      t.integer "fee_id"
      t.decimal "fee_total_amount", precision: 10
      t.boolean "with_voucher", default: false, null: false
      t.string "fee_type_code"
      t.boolean "member_notified", default: false
      t.boolean "from_app", default: false, null: false
      t.boolean "certificate_printed", default: false
      t.index ["author_id"], name: "index_qcontrols_on_author_id"
      t.index ["inspector_id"], name: "index_qcontrols_on_inspector_id"
      t.index ["person_id", "control_date", "group_id"], name: "index_qcontrols_on_person_control_date_and_group"
      t.index ["person_id"], name: "index_qcontrols_on_person_id"
    end
  end
end
