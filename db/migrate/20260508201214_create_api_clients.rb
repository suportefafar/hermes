class CreateApiClients < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.string :name
      t.string :token_digest
      t.boolean :active

      t.timestamps
    end
  end
end
