module TeacherPayouts
  extend ActiveSupport::Concern

  PAYOUT_METHODS = %w[bank_transfer wise paypal other].freeze

  included do
    has_many :earnings, dependent: :restrict_with_error
    has_many :payouts, dependent: :restrict_with_error

    # Bank or Wise/PayPal details are stored encrypted (see config/initializers/active_record_encryption.rb).
    encrypts :payout_details

    before_save :track_payout_changes

    validates :payout_method, inclusion: { in: PAYOUT_METHODS }, allow_blank: true
    validates :payout_details, length: { maximum: 500 }
  end

  def payout_ready?
    payout_method.present? && payout_details.present?
  end

  # Amounts in cents for the "My earnings" page.
  def earnings_summary
    sums = earnings.group(:status).sum(:amount_cents)
    {
      available: sums.fetch("available", 0),
      in_payout: sums.fetch("in_payout", 0),
      paid_out: sums.fetch("paid_out", 0),
      upcoming: Order.status_paid.joins(:lesson)
                     .where(lessons: { teacher_profile_id: id, status: "scheduled" })
                     .sum(:teacher_amount_cents)
    }
  end

  private

  def track_payout_changes
    self.payout_details_updated_at = Time.current if payout_details_changed? || payout_method_changed?
  end
end
