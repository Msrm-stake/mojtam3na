# Slows down password guessing and abuse. Counters live in this process, which is right for one web instance;
# use a shared cache store if the app is ever run on several instances.
class Rack::Attack
  Rack::Attack.enabled = false if Rails.env.test?
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  LOCALE_PREFIX = "(/(en|fr|es|it|ru|ar))?".freeze
  LOGIN_PATH = %r{\A#{LOCALE_PREFIX}/users/sign_in/?\z}
  SIGN_UP_PATH = %r{\A#{LOCALE_PREFIX}/users/?\z}
  PASSWORD_RESET_PATH = %r{\A#{LOCALE_PREFIX}/users/password/?\z}
  ACCOUNT_PATH = %r{\A#{LOCALE_PREFIX}/account(/export)?/?\z}
  BOOKING_PATH = %r{\A#{LOCALE_PREFIX}/teachers/\d+/lessons/?\z}

  def self.email_param(req)
    req.params.dig("user", "email").to_s.downcase.strip.presence
  rescue StandardError
    nil
  end

  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? && req.path.match?(LOGIN_PATH)
  end

  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    Rack::Attack.email_param(req) if req.post? && req.path.match?(LOGIN_PATH)
  end

  throttle("signups/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.post? && req.path.match?(SIGN_UP_PATH)
  end

  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path.match?(PASSWORD_RESET_PATH)
  end

  throttle("password_resets/email", limit: 3, period: 1.hour) do |req|
    Rack::Attack.email_param(req) if req.post? && req.path.match?(PASSWORD_RESET_PATH)
  end

  throttle("account_actions/ip", limit: 10, period: 15.minutes) do |req|
    req.ip if (req.post? || req.delete?) && req.path.match?(ACCOUNT_PATH)
  end

  throttle("bookings/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.post? && req.path.match?(BOOKING_PATH)
  end

  # A general limit per address. Assets, the health check and Stripe's webhook are never limited.
  throttle("requests/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/up", "/stripe/webhooks")
  end

  self.throttled_responder = lambda do |request|
    match = request.env["rack.attack.match_data"] || {}
    period = match[:period].to_i.nonzero? || 60
    retry_after = period - (Time.now.to_i % period)
    [
      429,
      { "Content-Type" => "text/plain; charset=utf-8", "Retry-After" => retry_after.to_s },
      ["Too many requests. Please wait a moment and try again.\nTrop de requêtes. Veuillez patienter un instant puis réessayer.\n"]
    ]
  end
end
