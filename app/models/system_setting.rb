class SystemSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  DEFAULTS = {
    "rate_limit_per_minute"    => "2",
    "fallback_threshold_pct"   => "50",
    "max_retry_attempts"       => "4"
  }.freeze

  def self.get(key)
    find_by(key: key)&.value || DEFAULTS[key.to_s]
  end

  def self.set(key, value)
    find_or_initialize_by(key: key).tap do |s|
      s.value = value.to_s
      s.save!
    end
  end

  def self.rate_limit_per_minute
    get("rate_limit_per_minute").to_i
  end

  def self.fallback_threshold_pct
    get("fallback_threshold_pct").to_i
  end

  def self.max_retry_attempts
    get("max_retry_attempts").to_i
  end
end
