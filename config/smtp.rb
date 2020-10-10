SMTP_SETTINGS = {
  address: ENV.fetch("SMTP_ADDRESS", nil), # example: "smtp.sendgrid.net"
  authentication: :plain,
  domain: ENV.fetch("SMTP_DOMAIN", nil), # example: "heroku.com"
  enable_starttls_auto: true,
  password: ENV.fetch("SMTP_PASSWORD", nil),
  port: "587",
  user_name: ENV.fetch("SMTP_USERNAME", nil)
}

if ENV["EMAIL_RECIPIENTS"].present?
  Mail.register_interceptor RecipientInterceptor.new(ENV["EMAIL_RECIPIENTS"])
end
