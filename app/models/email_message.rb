class EmailMessage < ApplicationRecord
  belongs_to :api_client, optional: true
  belongs_to :smtp_provider, optional: true
  has_many :delivery_attempts, dependent: :destroy

  enum :status, {
    pending:    0,
    sent:       1,
    failed:     2,
    malformed:  3
  }

  RETRY_DELAYS = [
    1.minute,
    30.minutes,
    8.hours,
    24.hours
  ].freeze

  validates :subject, presence: true
  validates :body_html, presence: true
  validates :to_addresses, presence: true

  scope :due_for_delivery, -> {
    where(status: :pending)
      .where("next_attempt_at <= ?", Time.current)
      .order(:next_attempt_at)
  }

  scope :retriable, -> { where(status: :pending) }

  def schedule_retry!(error_msg = nil)
    max = SystemSetting.max_retry_attempts
    new_attempts = attempts + 1

    if new_attempts >= max
      update!(status: :failed, error_message: error_msg, attempts: new_attempts)
    else
      delay = RETRY_DELAYS[new_attempts - 1] || 24.hours
      update!(
        attempts: new_attempts,
        next_attempt_at: Time.current + delay,
        error_message: error_msg
      )
    end
  end

  def mark_sent!(provider)
    update!(status: :sent, smtp_provider: provider, error_message: nil)
  end

  def mark_hard_failed!(error_msg)
    update!(status: :failed, error_message: error_msg)
  end

  def enqueue_manual_resend!
    update!(
      status: :pending,
      attempts: 0,
      next_attempt_at: Time.current,
      is_manual_resend: true,
      error_message: nil
    )
    SchedulerJob.perform_later
  end
end
