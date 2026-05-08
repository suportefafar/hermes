class CreateEmailMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :email_messages do |t|
      t.references :api_client, null: false, foreign_key: true
      t.references :smtp_provider, null: false, foreign_key: true
      t.integer :status
      t.integer :attempts
      t.datetime :next_attempt_at
      t.boolean :is_manual_resend
      t.string :from_address
      t.string :reply_to
      t.string :subject
      t.text :body_html
      t.text :error_message

      t.timestamps
    end
  end
end
