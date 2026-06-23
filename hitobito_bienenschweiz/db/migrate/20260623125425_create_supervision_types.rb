class CreateSupervisionTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :supervision_types do |t|
      t.string :name, null: false

      t.timestamps
      t.index :name, unique: true
    end

    add_column :supervisions, :supervision_type_id, :integer
    remove_column :supervisions, :course_type_id
  end
end
