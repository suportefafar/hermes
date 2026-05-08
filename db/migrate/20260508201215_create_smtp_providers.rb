class CreateSmtpProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :smtp_providers do |t|
      t.string :name
      t.string :host
      t.integer :port
      t.string :username
      t.string :encrypted_password
      t.string :from_address
      t.integer :priority
      t.boolean :active
      t.integer :failure_count
      t.datetime :last_used_at

      t.timestamps
    end
  end
end
