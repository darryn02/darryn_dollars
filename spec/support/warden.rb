# Signing in through the form on every system spec would spend most of the
# suite's time re-testing Devise. Warden's test mode injects the session
# directly, and works with the Capybara server because that server runs the
# same Rails app in this same process.
#
# The sign-in form itself is still covered, once, by its own spec.
RSpec.configure do |config|
  config.include Warden::Test::Helpers, type: :system

  config.before(:suite) { Warden.test_mode! }
  config.after(:each, type: :system) { Warden.test_reset! }
end
