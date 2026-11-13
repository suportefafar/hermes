require "minitest/autorun"
require "json"
require "active_record"
require "active_record/encryption"
require_relative "../lib/hermes_encryption"

class EncryptionRotationTest < Minitest::Test
  def setup
    @current = HermesEncryption.keys(HermesEncryption::VARIABLES.values.to_h { |name| [ name, SecureRandom.hex(32) ] })
    ActiveRecord::Encryption.configure(**@current)
    @previous = {
      "HERMES_ENCRYPTION_PREVIOUS_PRIMARY_KEY" => SecureRandom.hex(32),
      "HERMES_ENCRYPTION_PREVIOUS_KEY_DERIVATION_SALT" => SecureRandom.hex(32)
    }
  end

  def test_reads_previous_credentials_but_encrypts_using_only_new_keys
    previous_provider = HermesEncryption.previous_provider(@previous)
    old_ciphertext = ActiveRecord::Encryption.encryptor.encrypt("test-smtp-password", key_provider: previous_provider)
    old_scheme = ActiveRecord::Encryption::Scheme.new(key_provider: previous_provider)
    scheme = ActiveRecord::Encryption::Scheme.new(previous_schemes: [ old_scheme ])
    type = ActiveRecord::Encryption::EncryptedAttributeType.new(scheme: scheme)
    assert_equal "test-smtp-password", type.deserialize(old_ciphertext)
    new_ciphertext = type.serialize(type.deserialize(old_ciphertext))
    assert_equal "test-smtp-password", ActiveRecord::Encryption.encryptor.decrypt(new_ciphertext)
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      ActiveRecord::Encryption.encryptor.decrypt(new_ciphertext, key_provider: previous_provider)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      ActiveRecord::Encryption.encryptor.decrypt(old_ciphertext)
    end
  end

  def test_previous_keys_are_optional_and_must_be_provisioned_together
    assert_nil HermesEncryption.previous_provider({})
    @previous.each_key do |name|
      assert_raises(ArgumentError) { HermesEncryption.previous_provider(@previous.reject { |key, _| key == name }) }
    end
  end
end
