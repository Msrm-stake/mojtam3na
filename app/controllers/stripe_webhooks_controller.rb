# Receives payment notifications from Stripe. Nothing is trusted without a valid signature.
class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  HANDLED_EVENTS = %w[checkout.session.completed checkout.session.async_payment_succeeded].freeze

  def create
    secret = ENV["STRIPE_WEBHOOK_SECRET"]
    return head :service_unavailable if secret.blank?

    event = StripeClient.verify_signature!(
      payload: request.raw_post,
      header: request.headers["Stripe-Signature"],
      secret: secret
    )
    handle(event)
    head :ok
  rescue StripeClient::SignatureError
    head :bad_request
  rescue StandardError => e
    # A 500 makes Stripe try again later.
    Rails.logger.error("Stripe webhook failed: #{e.class}: #{e.message}")
    head :internal_server_error
  end

  private

  def handle(event)
    return unless HANDLED_EVENTS.include?(event["type"])

    session = event.dig("data", "object") || {}
    order = Order.find_by(stripe_checkout_session_id: session["id"])
    return if order.nil?

    outcome = order.settle!(session)
    order.lesson.notify_participants(:booked) if outcome == :confirmed
  end
end
