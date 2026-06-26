class AddCanceledToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :canceled, :boolean, null: false, default: false
  end
end
