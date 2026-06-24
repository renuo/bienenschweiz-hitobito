class AddCommentToSupervisions < ActiveRecord::Migration[8.0]
  def change
    add_column :supervisions, :comment, :string
  end
end
