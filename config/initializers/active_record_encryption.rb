# Keys for encrypted columns (teacher payout details). In development they live in .env.
# In production set the same three values as server environment variables and keep a backup:
# without them the saved details cannot be read.
Rails.application.config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
Rails.application.config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
Rails.application.config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
