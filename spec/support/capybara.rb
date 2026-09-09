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

# importmap ships application.js as a deferred ES module, so there is a window
# after the HTML is parsed where the DOM is complete but jQuery UJS and
# Bootstrap have bound nothing. A click landing inside it fails in ways that
# look nothing like the cause: a `method: :put` link performs a plain GET and
# lands on the wrong page, and a bet button is just an anchor that does nothing.
# It is intermittent, which makes it worse.
#
# application.js publishes showSuccessFlash on window as its last statement, so
# that is a truthful "everything above me has run" signal.
module WaitForApplicationJs
  READY = "typeof window.showSuccessFlash === 'function'".freeze

  def visit(*args)
    super

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    until page.evaluate_script(READY)
      # A page rendered without the application layout never defines it. Give
      # up quietly and let the example's own assertions report the real problem.
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.02
    end
  end

  # Polls a block on Capybara's clock. For the handful of waits that are about
  # browser state rather than the presence of a node, which is all the
  # have_css family can express.
  def wait_until(seconds = Capybara.default_max_wait_time)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

    loop do
      return true if yield
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end

    false
  end
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_mobile_chrome
  end

  config.include WaitForApplicationJs, type: :system
end
