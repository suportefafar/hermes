class ApiClient < ApplicationRecord
  has_many :email_messages, dependent: :nullify

  validates :name, presence: true
  validates :token_digest, presence: true

  scope :active, -> { where(active: true) }

  def self.generate_token
    SecureRandom.hex(32)
  end

  def self.find_by_token(raw_token)
    digest = Digest::SHA256.hexdigest(raw_token)
    active.find_by(token_digest: digest)
  end

  def token=(raw_token)
    self.token_digest = Digest::SHA256.hexdigest(raw_token)
  end
end
