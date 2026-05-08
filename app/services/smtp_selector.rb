class SmtpSelector
  # Returns the best provider to use for sending.
  # Applies fallback threshold logic: if the primary provider has failed
  # more than `fallback_threshold_pct`% of recent sends, use the next one.
  def self.select
    providers = SmtpProvider.active.to_a
    return nil if providers.empty?

    threshold = SystemSetting.fallback_threshold_pct

    providers.each do |provider|
      # Check if this provider is healthy enough
      total = recent_total(provider)
      if total > 0
        failure_pct = (provider.failure_count.to_f / total) * 100
        next if failure_pct >= threshold
      end

      return provider
    end

    # All providers above threshold — return primary anyway and let it fail
    providers.first
  end

  private

  def self.recent_total(provider)
    DeliveryAttempt
      .where(smtp_provider: provider)
      .where("attempted_at > ?", 1.hour.ago)
      .count
  end
end
