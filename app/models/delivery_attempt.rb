class DeliveryAttempt < ApplicationRecord
  belongs_to :email_message
  belongs_to :smtp_provider, optional: true

  enum :outcome, {
    delivered:    0,
    soft_bounce:  1,
    hard_bounce:  2,
    timed_out:    3,
    rate_limited: 4
  }

  validates :attempt_number, presence: true
  validates :outcome, presence: true
  validates :attempted_at, presence: true
end
