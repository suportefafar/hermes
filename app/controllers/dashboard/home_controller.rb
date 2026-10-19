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

      # Chart data: one point per hour, including the current hour
      chart_end = Time.current
      chart_start = chart_end.beginning_of_hour - 47.hours
      chart_range = chart_start..chart_end
      @emails_by_hour = [
        { name: "Sent", data: EmailMessage.sent.group_by_hour(:updated_at, range: chart_range, series: true).count },
        { name: "Failed", data: EmailMessage.failed.group_by_hour(:updated_at, range: chart_range, series: true).count }
      ]

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
