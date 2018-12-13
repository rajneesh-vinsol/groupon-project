class Coupon < ApplicationRecord
  # Associations
  belongs_to :line_item
  belongs_to :redeemed_by, class_name: 'User', optional: true
  # Callbacks
  before_create :create_coupon_code
  after_create_commit :send_coupon_code_email

  private def create_coupon_code
    loop do
      self.code = Tokenizer.new_token
      if Coupon.find_by(code: code).nil?
        break
      end
    end
  end

  private def send_coupon_code_email
    CouponMailer.send_coupon_email(id).deliver_later
  end

end
