class AddDiplomaFieldsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :diploma_location, :string
    add_column :events, :diploma_issued_at, :date
  end
end
