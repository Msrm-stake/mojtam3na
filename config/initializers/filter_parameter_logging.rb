# Parameters hidden from the logs. Emails, phone numbers and payout details are personal data.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :payout_details, :phone
]
