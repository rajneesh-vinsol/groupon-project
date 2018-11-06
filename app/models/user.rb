class User < ApplicationRecord
  
  ROLES = ({ customer: 0, admin: 1 }).freeze
  PASSWORD_VALIDATION_RANGE = (6..20).freeze

  has_secure_password

  enum role: ROLES

  # Validations
  validates :name, presence: true
  validates :email, presence: true
  validates :email, uniqueness: { case_sensitive: false }, format: {
    with:    EMAIL_REGEXP,
    message: :invalid_email
  }, allow_blank: true
  validates :verification_token, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :password, length: { in: PASSWORD_VALIDATION_RANGE }, allow_blank: true
  #Callbacks
  before_create :set_verification_token
  after_create_commit :send_verification_email

  def verify_email
    update_columns(verified_at: Time.current, verification_token: nil)
  end

  private
    def send_verification_email
      SendVerificationEmailJob.perform_later(id) if customer?
    end

    def set_verification_token
      if verification_token.present?
        return false
      end  
      loop do
        self.verification_token = SecureRandom.urlsafe_base64.to_s
        if User.find_by(verification_token: verification_token).nil?
          break
        end
      end
    end

end
