class AddRecipientsToEmailMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :email_messages, :to_addresses, :string, array: true, default: []
    add_column :email_messages, :cc_addresses, :string, array: true, default: []
    add_column :email_messages, :bcc_addresses, :string, array: true, default: []
    add_column :email_messages, :attachments, :jsonb, default: []

    add_index :email_messages, :to_addresses, using: :gin
    add_index :email_messages, :status
    add_index :email_messages, :next_attempt_at
    add_index :email_messages, :api_client_id
  end
end
