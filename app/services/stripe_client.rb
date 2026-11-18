require "net/http"
require "json"
require "openssl"

# Minimal client for the Stripe REST API (Checkout sessions and refunds) plus webhook signature checks.
# The secret key comes from the environment (.env in development) and never appears in code or logs.
class StripeClient
  class Error < StandardError
    attr_reader :code

    def initialize(message = nil, code: nil)
      super(message)
      @code = code
    end
  end
  class NotConfigured < Error; end
  class SignatureError < Error; end

  BASE = "https://api.stripe.com/v1".freeze
  CHECKOUT_LOCALES = %w[en fr es it ru].freeze
  WEBHOOK_TOLERANCE = 300

  def self.configured?
    ENV["STRIPE_SECRET_KEY"].present?
  end

  # Checks that a webhook really comes from Stripe. Returns the parsed event, or raises SignatureError.
  def self.verify_signature!(payload:, header:, secret:, now: Time.current, tolerance: WEBHOOK_TOLERANCE)
    raise SignatureError, "Webhook secret is not set" if secret.blank?

    parts = header.to_s.split(",").map { |item| item.split("=", 2) }.select { |pair| pair.size == 2 }
    timestamp = parts.to_h.fetch("t", "0").to_i
    signatures = parts.select { |key, _| key == "v1" }.map(&:last)
    raise SignatureError, "Missing signature" if timestamp.zero? || signatures.empty?
    raise SignatureError, "Timestamp outside tolerance" if (now.to_i - timestamp).abs > tolerance

    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    valid = signatures.any? { |signature| ActiveSupport::SecurityUtils.secure_compare(signature, expected) }
    raise SignatureError, "Signature mismatch" unless valid

    JSON.parse(payload)
  end

  def initialize(api_key: ENV["STRIPE_SECRET_KEY"])
    raise NotConfigured, "STRIPE_SECRET_KEY is not set" if api_key.blank?

    @api_key = api_key
  end

  # A Stripe-hosted payment page for one lesson. Stripe requires 30 minutes to 24 hours of life.
  def create_checkout_session(order_id:, lesson_id:, amount_cents:, currency:, product_name:, email:,
                              success_url:, cancel_url:, expires_at:, locale: nil)
    params = {
      mode: "payment",
      client_reference_id: order_id.to_s,
      customer_email: email,
      success_url: success_url,
      cancel_url: cancel_url,
      expires_at: expires_at.to_i,
      line_items: {
        "0" => {
          quantity: 1,
          price_data: { currency: currency.to_s.downcase, unit_amount: amount_cents,
                        product_data: { name: product_name } }
        }
      },
      metadata: { order_id: order_id, lesson_id: lesson_id },
      payment_intent_data: { metadata: { order_id: order_id, lesson_id: lesson_id } }
    }
    params[:locale] = locale.to_s if CHECKOUT_LOCALES.include?(locale.to_s)

    post("/checkout/sessions", params, idempotency_key: "checkout-order-#{order_id}")
  end

  def retrieve_checkout_session(id)
    get("/checkout/sessions/#{URI.encode_www_form_component(id)}")
  end

  def expire_checkout_session(id)
    post("/checkout/sessions/#{URI.encode_www_form_component(id)}/expire", {})
  end

  # A full refund of one payment. The idempotency key makes a repeated call safe.
  def create_refund(payment_intent:, idempotency_key:, metadata: {})
    post("/refunds",
         { payment_intent: payment_intent, reason: "requested_by_customer", metadata: metadata },
         idempotency_key: idempotency_key)
  end

  private

  def get(path)
    request(Net::HTTP::Get, path)
  end

  def post(path, params, idempotency_key: nil)
    request(Net::HTTP::Post, path, params, idempotency_key)
  end

  def request(verb, path, params = nil, idempotency_key = nil)
    uri = URI("#{BASE}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 15

    req = verb.new(uri)
    req["Authorization"] = "Bearer #{@api_key}"
    req["Idempotency-Key"] = idempotency_key if idempotency_key
    if params
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = Rack::Utils.build_nested_query(params)
    end

    response = http.request(req)
    parsed = response.body.present? ? JSON.parse(response.body) : {}
    return parsed if response.is_a?(Net::HTTPSuccess)

    details = parsed["error"] || {}
    raise Error.new("Stripe API #{response.code}: #{details['message'] || 'request failed'}", code: details["code"])
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, JSON::ParserError => e
    raise Error, "Stripe API unreachable (#{e.class})"
  end
end
