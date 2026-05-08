class CreateDeliveryAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :delivery_attempts do |t|
      t.references :email_message, null: false, foreign_key: true
      t.references :smtp_provider, null: false, foreign_key: true
      t.integer :attempt_number
      t.integer :smtp_response_code
      t.text :smtp_response_msg
      t.integer :outcome
      t.datetime :attempted_at

      t.timestamps
    end
  end
end
