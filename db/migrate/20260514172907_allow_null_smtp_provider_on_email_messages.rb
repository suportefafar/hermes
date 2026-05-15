class AllowNullSmtpProviderOnEmailMessages < ActiveRecord::Migration[8.1]
  def change
    change_column_null :email_messages, :smtp_provider_id, true
  end
end
