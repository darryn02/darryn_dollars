class ApplicationMailer < ActionMailer::Base
  default from: MAILER_SENDER
  layout 'mailer'
end
