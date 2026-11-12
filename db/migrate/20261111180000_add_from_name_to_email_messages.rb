class AddFromNameToEmailMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :email_messages, :from_name, :string, limit: 255
  end
end
