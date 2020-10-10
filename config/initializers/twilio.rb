Twilio.configure do |config|
  config.account_sid = Rails.application.secrets.sms_provider_id
  config.auth_token = Rails.application.secrets.sms_provider_secret
end
