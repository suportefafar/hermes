class SchedulerJob < ApplicationJob
  queue_as :default

  def perform
    EmailMessage.due_for_delivery.each do |message|
      # Manual resends bypass the rate limiter
      if message.is_manual_resend?
        DeliveryJob.perform_later(message.id)
        next
      end

      if RateLimiter.throttled?
        # Requeue with a small delay — does not consume a retry
        message.update_column(:next_attempt_at, 5.seconds.from_now)
        next
      end

      RateLimiter.increment!
      DeliveryJob.perform_later(message.id)
    end
  end
end
