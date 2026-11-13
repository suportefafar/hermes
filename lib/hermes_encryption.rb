require "securerandom"
require "digest"

module HermesEncryption
  VARIABLES = {
    primary_key: "HERMES_ENCRYPTION_PRIMARY_KEY",
    deterministic_key: "HERMES_ENCRYPTION_DETERMINISTIC_KEY",
    key_derivation_salt: "HERMES_ENCRYPTION_KEY_DERIVATION_SALT"
  }.freeze

  PUBLIC_KEY_FINGERPRINTS = %w[
    16fa84fd1f7fe2c9a40a476f220d6446cf42831a40d0ea431bb1102760a7aa07
    9e3e476fa39fd4c8ad6d550adc23577f6121231de940f7a52926fc00a7292138
    5fd87038e8693dd89db9e449c0d2bccfa7602b09d88aa97bbc5bca44aeb57ec6
  ].freeze

  def self.keys(env = ENV, asset_build: false)
    # Asset compilation has no database access and must not receive runtime secrets.
    if env["SECRET_KEY_BASE_DUMMY"] == "1"
      raise ArgumentError, "SECRET_KEY_BASE_DUMMY is only allowed for assets:precompile" unless asset_build

      return VARIABLES.transform_values { SecureRandom.hex(32) }
    end

    keys = VARIABLES.transform_values do |name|
      value = env[name].to_s
      if value.strip.length < 32 || value.include?("__REQUIRED__") || PUBLIC_KEY_FINGERPRINTS.include?(Digest::SHA256.hexdigest(value))
        raise ArgumentError, "#{name} must contain a new private key of at least 32 characters"
      end
      value
    end
    raise ArgumentError, "Encryption keys must be independent" unless keys.values.uniq.length == keys.length

    keys
  end

  # Only used to read SMTP credentials during a controlled key rotation.
  def self.previous_provider(env = ENV)
    names = %w[HERMES_ENCRYPTION_PREVIOUS_PRIMARY_KEY HERMES_ENCRYPTION_PREVIOUS_KEY_DERIVATION_SALT]
    return unless names.any? { |name| env.key?(name) }

    primary, salt = names.map do |name|
      value = env[name].to_s
      raise ArgumentError, "#{name} is required during encryption rotation" if value.strip.length < 32 || value.include?("__REQUIRED__")

      value
    end
    key = ActiveSupport::KeyGenerator.new(primary, hash_digest_class: ActiveRecord::Encryption.config.hash_digest_class)
      .generate_key(salt, ActiveRecord::Encryption.cipher.key_length)
    ActiveRecord::Encryption::KeyProvider.new([ ActiveRecord::Encryption::Key.new(key) ])
  end
end
