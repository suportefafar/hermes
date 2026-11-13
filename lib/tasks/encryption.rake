namespace :hermes do
  desc "Re-encrypt SMTP credentials with current private keys after provisioning previous keys"
  task rotate_encryption: :environment do
    abort "Configure previous encryption keys before running this task" unless HermesEncryption.previous_provider

    begin
      count = 0
      SmtpProvider.transaction do
        SmtpProvider.order(:id).lock.each do |provider|
          password = provider.password
          provider.encrypt
          ciphertext = provider.reload.read_attribute_before_type_cast(:encrypted_password)
          if password && ActiveRecord::Encryption.encryptor.decrypt(ciphertext) != password
            raise "Encryption verification failed"
          end
          count += 1
        end
      end
      puts "SMTP credentials re-encrypted and verified: #{count}"
    rescue StandardError => error
      abort "Encryption migration rolled back (#{error.class.name}); no secret values disclosed"
    end
  end
end
