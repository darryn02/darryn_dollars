require_relative 'boot'
require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
Bundler.require(*Rails.groups)

# Every outgoing address, in one place. The display name is what recipients
# actually see; the address has to stay on darryndollars.com, which is the
# domain SendGrid signs for - anything else fails DMARC alignment.
MAILER_SENDER = ENV.fetch("MAILER_SENDER", "Darryn Dollars <no-reply@darryndollars.com>")

module DarrynDollars
  class Application < Rails::Application
    config.assets.quiet = true
    config.generators do |generate|
      generate.helper false
      generate.javascripts false
      generate.request_specs false
      generate.routing_specs false
      generate.stylesheets false
      generate.test_framework :rspec
      generate.view_specs false
    end
    config.action_controller.action_on_unpermitted_parameters = :log
    config.active_job.queue_adapter = :delayed_job

    config.time_zone = 'Eastern Time (US & Canada)'
    config.active_record.default_timezone = :local
  end
end
