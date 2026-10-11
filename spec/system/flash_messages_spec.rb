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

  # The scoring buttons on the admin dashboard answer with a report of
  # several lines. The controller joined them with <br>, the script rendered
  # the message as text, and the book read the tag: "BUF +2.5 -> win<br>MIA".
  describe "a report of several lines on the admin dashboard" do
    let(:user) { create_user(name: "The Book", admin: true) }

    def report_text
      find(".flash-from-js div").text
    end

    it "puts each line on its own line" do
      allow(LineScorer).to receive(:run).and_return("BUF +2.5 -> win\nMIA -2.5 -> loss")

      visit admin_dashboard_path
      click_link "Score Lines"

      expect(page).to have_css(".flash-from-js div")
      expect(report_text).to eq("BUF +2.5 -> win\nMIA -2.5 -> loss")
    end

    # A report is built from team names that arrive from a scrape. It is shown
    # as text so that markup in one is something to read, not something the
    # browser acts on.
    it "shows markup inside a report as text" do
      allow(LineScorer).to receive(:run).and_return("<img src=x> Bills\nscored")

      visit admin_dashboard_path
      click_link "Score Lines"

      expect(page).to have_css(".flash-from-js div")
      expect(report_text).to eq("<img src=x> Bills\nscored")
      expect(page).to have_no_css(".flash-from-js img")
    end
  end
end
