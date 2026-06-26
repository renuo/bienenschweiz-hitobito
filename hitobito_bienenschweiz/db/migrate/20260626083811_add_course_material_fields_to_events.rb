class AddCourseMaterialFieldsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :delivery_address, :text
    add_column :events, :billing_address, :text
  end
end
