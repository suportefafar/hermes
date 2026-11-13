require "securerandom"

module HermesEncryption
  VARIABLES = {
    primary_key: "HERMES_ENCRYPTION_PRIMARY_KEY",
    deterministic_key: "HERMES_ENCRYPTION_DETERMINISTIC_KEY",
    key_derivation_salt: "HERMES_ENCRYPTION_KEY_DERIVATION_SALT"
  }.freeze

  def self.keys(env = ENV, asset_build: false)
    # Asset compilation has no database access and must not receive runtime secrets.
    if env["SECRET_KEY_BASE_DUMMY"] == "1"
      raise ArgumentError, "SECRET_KEY_BASE_DUMMY is only allowed for assets:precompile" unless asset_build

      return VARIABLES.transform_values { SecureRandom.hex(32) }
    end

    keys = VARIABLES.transform_values do |name|
      value = env[name].to_s
      if value.strip.length < 32 || value.include?("__REQUIRED__")
        raise ArgumentError, "#{name} must contain a private key of at least 32 characters"
      end
      value
    end
    raise ArgumentError, "Encryption keys must be independent" unless keys.values.uniq.length == keys.length

    keys
  end
end
