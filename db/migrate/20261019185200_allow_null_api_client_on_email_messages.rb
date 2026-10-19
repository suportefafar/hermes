class AllowNullApiClientOnEmailMessages < ActiveRecord::Migration[8.1]
  def change
    change_column_null :email_messages, :api_client_id, true
  end
end
