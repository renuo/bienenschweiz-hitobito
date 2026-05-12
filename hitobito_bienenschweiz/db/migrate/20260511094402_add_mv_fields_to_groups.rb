class AddMvFieldsToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :code, :integer, null: true
    add_index :groups, :code, unique: true
  end
end
