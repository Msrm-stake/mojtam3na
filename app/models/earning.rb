class Earning < ApplicationRecord
  belongs_to :teacher_profile
  belongs_to :lesson
  belongs_to :order
  belongs_to :payout, optional: true

  enum :status, { available: "available", in_payout: "in_payout", paid_out: "paid_out" }, prefix: true

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  # One earning per paid lesson, created when the lesson is confirmed. Free trials earn nothing.
  def self.record_for!(lesson, now: Time.current)
    order = lesson.order
    return unless order&.status_paid?

    find_or_create_by!(lesson_id: lesson.id) do |earning|
      earning.teacher_profile_id = lesson.teacher_profile_id
      earning.order_id = order.id
      earning.amount_cents = order.teacher_amount_cents
      earning.currency = order.currency
      earning.earned_at = now
    end
  end
end
