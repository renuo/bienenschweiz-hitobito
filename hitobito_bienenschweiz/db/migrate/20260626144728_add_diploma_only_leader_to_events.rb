class AddDiplomaOnlyLeaderToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :diploma_only_leader, :boolean, default: false, null: false
  end
end
