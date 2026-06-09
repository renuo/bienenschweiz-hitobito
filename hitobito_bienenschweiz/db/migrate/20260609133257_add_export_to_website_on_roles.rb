class AddExportToWebsiteOnRoles < ActiveRecord::Migration[8.0]
  def change
    add_column :roles, :export_to_website, :boolean, default: true, null: false
  end
end
