require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store, { size: 64.megabytes }

  # Assets are compiled while the image is built (see the Dockerfile) and served by Rails.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.assets.compile = false

  # Uploaded certificates go to a private EU bucket (config/storage.yml).
  config.active_storage.service = :s3_eu

  # Render ends TLS in front of the app. Force HTTPS, but let the health check through.
  config.assume_ssl = true
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Only answer for our own host names (the health check is exempt).
  hosts = [ENV["APP_HOST"], ENV["RENDER_EXTERNAL_HOSTNAME"]].compact_blank
  if hosts.any?
    config.hosts = hosts
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  # Jobs (emails, reminders, maintenance) are stored in the main database and run inside the web process.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.silence_polling = true

  # Email through Brevo's SMTP (set SMTP_USERNAME, SMTP_PASSWORD and MAILER_FROM on the server).
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST") { ENV.fetch("RENDER_EXTERNAL_HOSTNAME", "localhost") },
    protocol: "https"
  }
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS", "smtp-relay.brevo.com"),
    port: ENV.fetch("SMTP_PORT", "587").to_i,
    user_name: ENV["SMTP_USERNAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true,
    open_timeout: 5,
    read_timeout: 10
  }
end
