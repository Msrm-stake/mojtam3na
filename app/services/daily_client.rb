require "net/http"
require "json"

# Minimal client for the Daily REST API (rooms and meeting tokens).
# Keys come from the environment (.env in development); they never appear in code or logs.
class DailyClient
  class Error < StandardError; end
  class NotConfigured < Error; end

  BASE = "https://api.daily.co/v1".freeze
  UI_LANGUAGES = %w[en fr es it ru].freeze

  def self.configured?
    ENV["DAILY_API_KEY"].present?
  end

  def initialize(api_key: ENV["DAILY_API_KEY"])
    raise NotConfigured, "DAILY_API_KEY is not set" if api_key.blank?

    @api_key = api_key
  end

  # A private room: nobody can enter without a personal token. Recording and chat stay off.
  def create_room(name:, starts_at:, ends_at:)
    request(:post, "/rooms", {
      name: name,
      privacy: "private",
      properties: {
        nbf: (starts_at - 10.minutes).to_i,
        exp: (ends_at + 30.minutes).to_i,
        max_participants: 4,
        enable_prejoin_ui: true,
        enable_chat: false,
        enable_knocking: false,
        eject_at_room_exp: true
      }
    })
  rescue Error => e
    raise unless e.message.include?("already exists")

    get_room(name)
  end

  def get_room(name)
    request(:get, "/rooms/#{URI.encode_www_form_component(name)}")
  end

  def delete_room(name)
    request(:delete, "/rooms/#{URI.encode_www_form_component(name)}")
  end

  # A token for one person and one room only, with a start and an end time.
  def create_token(room_name:, user_name:, owner:, starts_at:, ends_at:, lang: nil)
    properties = {
      room_name: room_name,
      user_name: user_name,
      is_owner: owner,
      nbf: (starts_at - Lesson::JOIN_OPENS).to_i,
      exp: (ends_at + Lesson::JOIN_CLOSES + 5.minutes).to_i,
      eject_at_token_exp: true
    }
    properties[:lang] = lang.to_s if UI_LANGUAGES.include?(lang.to_s)

    request(:post, "/meeting-tokens", { properties: properties }).fetch("token")
  end

  private

  def request(method, path, body = nil)
    uri = URI("#{BASE}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    verb = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method)
    req = verb.new(uri)
    req["Authorization"] = "Bearer #{@api_key}"
    req["Content-Type"] = "application/json"
    req.body = body.to_json if body

    response = http.request(req)
    parsed = response.body.present? ? JSON.parse(response.body) : {}
    return parsed if response.is_a?(Net::HTTPSuccess)

    raise Error, "Daily API #{response.code}: #{parsed['info'] || parsed['error'] || 'request failed'}"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, JSON::ParserError => e
    raise Error, "Daily API unreachable (#{e.class})"
  end
end
