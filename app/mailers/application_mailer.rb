class ApplicationMailer < ActionMailer::Base
  include ApplicationHelper
  helper ApplicationHelper

  # Set MAILER_FROM in production once the sending domain is ready.
  default from: ENV.fetch("MAILER_FROM", "Mojtam3na <no-reply@example.com>")
  layout "mailer"
end
