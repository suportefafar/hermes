class DeliveryJob < ApplicationJob
  queue_as :default

  # SMTP response code classification
  HARD_BOUNCE_CODES = (500..599).freeze
  SOFT_BOUNCE_CODES = (400..499).freeze

  def perform(email_message_id)
    message = EmailMessage.find_by(id: email_message_id)
    return unless message&.pending?

    provider = SmtpSelector.select

    unless provider
      message.schedule_retry!("No active SMTP providers configured")
      record_attempt(message, nil, nil, nil, :soft_bounce)
      return
    end

    begin
      HermesMailer.send_email(message, provider).deliver_now

      provider.update_column(:last_used_at, Time.current)
      provider.reset_failure_count!
      message.mark_sent!(provider)
      record_attempt(message, provider, 250, "OK", :delivered)

    rescue Net::SMTPAuthenticationError,
           Net::SMTPFatalError => e
      # 5xx — hard bounce, no retry
      code = extract_code(e)
      provider.increment_failure!
      message.mark_hard_failed!(e.message)
      record_attempt(message, provider, code, e.message, :hard_bounce)

    rescue Net::SMTPServerBusy,
           Net::SMTPUnknownError,
           Timeout::Error,
           Errno::ECONNREFUSED,
           Errno::ECONNRESET => e
      # 4xx / network error — soft bounce, schedule retry
      code = extract_code(e)
      provider.increment_failure!
      message.schedule_retry!(e.message)
      record_attempt(message, provider, code, e.message, :soft_bounce)

    rescue => e
      # Unknown error — treat as soft bounce
      provider.increment_failure! if provider
      message.schedule_retry!(e.message)
      record_attempt(message, provider, nil, e.message, :soft_bounce)
    end
  end

  private

  def record_attempt(message, provider, code, msg, outcome)
    DeliveryAttempt.create!(
      email_message:     message,
      smtp_provider:     provider,
      attempt_number:    message.attempts,
      smtp_response_code: code,
      smtp_response_msg: msg,
      outcome:           outcome,
      attempted_at:      Time.current
    )
  end

  def extract_code(error)
    error.message.match(/\A(\d{3})/)&.[](1)&.to_i
  end
end
