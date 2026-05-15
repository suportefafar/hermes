module Dashboard
  class HomeController < BaseController
    def index
      @total_pending = EmailMessage.pending.count
      @total_sent    = EmailMessage.sent.count
      @total_failed  = EmailMessage.failed.count
      @total_malformed = EmailMessage.malformed.count

      @today_sent    = EmailMessage.sent.where("updated_at >= ?", Time.current.beginning_of_day).count
      @today_failed  = EmailMessage.failed.where("updated_at >= ?", Time.current.beginning_of_day).count

      @recent_messages = EmailMessage.order(created_at: :desc).limit(20).includes(:api_client)

      # Chart data: emails per day (last 14 days)
      @emails_by_day = EmailMessage
        .where("created_at > ?", 14.days.ago)
        .group_by_day(:created_at)
        .group(:status)
        .count

      # Warning: primary provider degraded and no fallback
      primary = SmtpProvider.active.first
      fallback = SmtpProvider.active.offset(1).first
      @provider_warning = primary && fallback.nil? &&
                          primary.failure_count > 0 &&
                          (primary.failure_count.to_f / [ recent_total(primary), 1 ].max * 100) >= SystemSetting.fallback_threshold_pct
    end

    private

    def recent_total(provider)
      DeliveryAttempt.where(smtp_provider: provider).where("attempted_at > ?", 1.hour.ago).count
    end
  end
end
