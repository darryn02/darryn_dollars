require "capybara/rspec"
require "selenium-webdriver"

# The site is used on phones and nowhere else, so the specs drive a phone-sized
# viewport. This is not cosmetic: the regression that hid the sport dropdowns
# was an `overflow-x: auto` on a strip that only scrolls at narrow widths, and a
# desktop-sized window would not have reproduced it.
Capybara.register_driver :headless_mobile_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--no-sandbox")
  options.add_argument("--window-size=390,844")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.server = :puma, { Silent: true }

# Bootstrap's offcanvas and dropdown both animate, and both are driven by
# transitionend. Five seconds is enough for the animation plus the synchronous
# XHR the test layout forces, without turning a genuine failure into a long wait.
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_mobile_chrome
  end
end
