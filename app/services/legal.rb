# Company details for the legal pages, read from config/legal.yml.
module Legal
  PLACEHOLDER = /\[[^\]]+\]/

  def self.settings
    Rails.application.config_for(:legal)
  end

  def self.value(key)
    settings.fetch(key.to_sym).to_s
  end

  def self.placeholder?(key)
    PLACEHOLDER.match?(value(key))
  end

  # Details that still contain a [PLACEHOLDER].
  def self.missing
    settings.keys.select { |key| placeholder?(key) }
  end

  def self.incomplete?
    missing.any?
  end
end
