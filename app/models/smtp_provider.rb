class SmtpProvider < ApplicationRecord
  has_many :email_messages, dependent: :nullify
  has_many :delivery_attempts, dependent: :nullify

  validates :name, presence: true
  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true }
  validates :from_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :priority, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(active: true).order(:priority) }
  scope :primary, -> { active.first }

  # Encrypt password at rest using Rails encryption
  encrypts :encrypted_password

  def password
    encrypted_password
  end

  def password=(val)
    self.encrypted_password = val
  end

  def reset_failure_count!
    update_column(:failure_count, 0)
  end

  def increment_failure!
    increment!(:failure_count)
  end
end
