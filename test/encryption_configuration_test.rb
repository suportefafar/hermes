require "minitest/autorun"
require_relative "../lib/hermes_encryption"

class EncryptionConfigurationTest < Minitest::Test
  def valid_env
    HermesEncryption::VARIABLES.values.to_h { |name| [ name, SecureRandom.hex(32) ] }
  end

  def test_preserves_provisioned_keys
    env = valid_env
    assert_equal env.values, HermesEncryption.keys(env).values
  end

  def test_rejects_missing_blank_placeholder_and_old_short_keys
    [ nil, "", " " * 32, "__REQUIRED__", "x" * 30 ].each do |value|
      env = valid_env.merge("HERMES_ENCRYPTION_PRIMARY_KEY" => value)
      error = assert_raises(ArgumentError) { HermesEncryption.keys(env) }
      assert_includes error.message, "HERMES_ENCRYPTION_PRIMARY_KEY"
      refute_includes error.message, "x" * 30
    end
  end

  def test_requires_every_key_and_salt
    HermesEncryption::VARIABLES.each_value do |name|
      env = valid_env
      env.delete(name)
      assert_raises(ArgumentError) { HermesEncryption.keys(env) }
    end
  end

  def test_rejects_reused_keys
    env = HermesEncryption::VARIABLES.values.to_h { |name| [ name, "x" * 32 ] }
    assert_raises(ArgumentError) { HermesEncryption.keys(env) }
  end

  def test_dummy_environment_cannot_bypass_runtime_validation
    assert_raises(ArgumentError) { HermesEncryption.keys("SECRET_KEY_BASE_DUMMY" => "1") }
    assert_raises(ArgumentError) { HermesEncryption.keys(valid_env.merge("SECRET_KEY_BASE_DUMMY" => "1")) }
  end

  def test_build_keys_are_ephemeral_and_do_not_use_runtime_secrets
    env = valid_env.merge("SECRET_KEY_BASE_DUMMY" => "1")
    first = HermesEncryption.keys(env, asset_build: true)
    second = HermesEncryption.keys(env, asset_build: true)
    assert_equal 3, first.values.uniq.length
    assert first.values.all? { |value| value.length >= 32 }
    assert_empty first.values & second.values
    assert_empty first.values & env.values
    assert_equal 3, HermesEncryption.keys({ "SECRET_KEY_BASE_DUMMY" => "1" }, asset_build: true).length
  end
end
