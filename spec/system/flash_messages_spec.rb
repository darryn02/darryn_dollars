require "rails_helper"

RSpec.describe "Flash messages raised from JavaScript", type: :system do
  let(:user) { create_user(name: "Dana Player") }
  let!(:account) { create_account(user: user) }

  before { login_as(user, scope: :user) }

  # Each flash set a five second timer to empty the banner and never cancelled
  # the one before it, so the first flash's timer emptied the second. Adding
  # two bets a few seconds apart lost the second confirmation early.
  #
  # Called directly rather than by placing two bets, because the timer is the
  # mechanism and two bets would bury it under two page interactions.
  it "gives a second flash its own five seconds rather than the first one's leftovers" do
    visit lines_path

    page.execute_script("window.showSuccessFlash('first bet')")
    sleep 3
    page.execute_script("window.showSuccessFlash('second bet')")

    # Five and a half seconds after the first, two and a half after the second.
    sleep 2.5

    expect(page).to have_css(".flash-from-js", text: "second bet", wait: 0)
  end
end
