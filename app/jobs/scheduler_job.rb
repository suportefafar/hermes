class SchedulerJob < ApplicationJob
  queue_as :default

  def perform
    recheck_at = nil

    EmailMessage.due_for_delivery.each do |message|
      # Manual resends bypass the rate limiter
      if message.is_manual_resend?
        DeliveryJob.perform_later(message.id)
        next
      end

      if RateLimiter.throttled?
        # Requeue with a small delay — does not consume a retry
        next_attempt_at = 5.seconds.from_now
        message.update_column(:next_attempt_at, next_attempt_at)
        recheck_at = [ recheck_at, next_attempt_at ].compact.min
        next
      end

      RateLimiter.increment!
      DeliveryJob.perform_later(message.id)
    end

    SchedulerJob.set(wait_until: recheck_at).perform_later if recheck_at
  end
end
