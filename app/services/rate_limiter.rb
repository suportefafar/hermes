class RateLimiter
  WINDOW = 60 # seconds

  def self.throttled?
    limit = SystemSetting.rate_limit_per_minute
    count = recent_count
    count >= limit
  end

  def self.increment!
    Rails.cache.increment(cache_key, 1, expires_in: WINDOW.seconds, raw: true)
  rescue
    # Cache unavailable — fail open (allow send)
  end

  private

  def self.cache_key
    window = (Time.current.to_i / WINDOW)
    "hermes:rate_limit:#{window}"
  end

  def self.recent_count
    Rails.cache.read(cache_key, raw: true).to_i
  rescue
    0
  end
end
