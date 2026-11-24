# Queues the owner emails. A failure here must never break a sign-up or an upload, so errors are only logged.
class AdminNotifier
  def self.new_teacher(user)
    safely { AdminMailer.new_teacher(user).deliver_later }
  end

  def self.qualification_added(qualification)
    safely { AdminMailer.qualification_added(qualification).deliver_later }
  end

  def self.safely
    yield
  rescue StandardError => e
    Rails.logger.warn("Admin notification not queued: #{e.class}")
  end
end
