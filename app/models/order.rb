class Order < ApplicationRecord
  # The platform keeps 20% of each lesson; the teacher's share is the remainder, so no cent is ever lost.
  COMMISSION_PERCENT = 20

  belongs_to :lesson
  belongs_to :parent, class_name: "User"

  enum :status,
       { pending: "pending", paid: "paid", refund_pending: "refund_pending", refunded: "refunded", expired: "expired" },
       prefix: true

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, inclusion: { in: %w[EUR] }
  validate :amounts_must_add_up

  def self.split(amount_cents)
    commission = (amount_cents * COMMISSION_PERCENT + 50) / 100
    [commission, amount_cents - commission]
  end

  def self.for_lesson(lesson)
    commission, teacher_share = split(lesson.price_cents)
    new(lesson: lesson, parent: lesson.booked_by, amount_cents: lesson.price_cents,
        commission_cents: commission, teacher_amount_cents: teacher_share, currency: lesson.currency)
  end

  # Confirms a payment. Called by the webhook and by the page the parent returns to,
  # so it is safe to run any number of times. Returns :ignored, :already, :confirmed or :refund_needed.
  def settle!(session, client: nil)
    return :ignored unless session["payment_status"] == "paid"

    outcome = :already
    lesson.with_lock do
      reload
      next unless status_pending? || status_expired?

      update!(status: "paid", paid_at: Time.current, stripe_payment_intent_id: session["payment_intent"])
      if lesson.status_pending_payment?
        lesson.update!(status: "scheduled", hold_expires_at: nil)
        outcome = :confirmed
      else
        # The held time was already released: the money goes back to the parent.
        update!(status: "refund_pending")
        outcome = :refund_needed
      end
    end

    refund!(client: client) if outcome == :refund_needed
    outcome
  end

  def request_refund!
    update!(status: "refund_pending") if status_paid?
  end

  # Sends the refund to Stripe. Returns true when done, false when it must be retried later.
  def refund!(client: nil)
    return false unless status_refund_pending?

    client ||= StripeClient.new
    refund = client.create_refund(payment_intent: stripe_payment_intent_id,
                                  idempotency_key: "refund-order-#{id}", metadata: { order_id: id })
    update!(status: "refunded", refunded_at: Time.current, stripe_refund_id: refund["id"])
    true
  rescue StripeClient::Error => e
    if e.code == "charge_already_refunded"
      update!(status: "refunded", refunded_at: Time.current)
      true
    else
      Rails.logger.error("Refund for order #{id} failed: #{e.message}")
      false
    end
  end

  # The parent left the payment page: free the held time at once.
  def abandon!(client: nil)
    expire_stripe_session(client)
    lesson.with_lock do
      reload
      next unless status_pending? && lesson.status_pending_payment?

      update!(status: "expired")
      lesson.update!(status: "expired")
    end
  end

  private

  def expire_stripe_session(client)
    return if stripe_checkout_session_id.blank?

    (client || StripeClient.new).expire_checkout_session(stripe_checkout_session_id)
  rescue StripeClient::Error => e
    Rails.logger.error("Could not expire Stripe session for order #{id}: #{e.message}")
  end

  def amounts_must_add_up
    return unless amount_cents && commission_cents && teacher_amount_cents

    errors.add(:amount_cents, :invalid) unless commission_cents + teacher_amount_cents == amount_cents
  end
end
