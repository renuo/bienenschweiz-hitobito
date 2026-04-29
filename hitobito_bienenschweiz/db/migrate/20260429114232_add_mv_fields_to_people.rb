class AddMvFieldsToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :salutation, :string
    add_column :people, :hive_count, :string
    add_column :people, :honey_yield, :string
    add_column :people, :export_to_website, :boolean, default: true, null: false
  end
end
