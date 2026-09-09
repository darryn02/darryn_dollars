require "rails_helper"

# Every other system spec injects the session through Warden, which is the right
# trade for the other twenty-odd examples but means nothing exercises the form
# itself. This one does, so the login page cannot break unnoticed.
RSpec.describe "Signing in", type: :system do
  let!(:user) { create_user(name: "Dana Player", email: "dana@example.com", password: "password123") }
  let!(:account) { create_account(user: user) }

  it "takes a player from the login form to the board" do
    visit new_user_session_path

    fill_in "Email", with: "dana@example.com"
    fill_in "Password", with: "password123"
    click_button "Log in"

    expect(page).to have_css(".dd-page-title", text: "Lines")
    expect(page).to have_css(".dd-bottom-nav")
  end

  it "keeps the wrong password out" do
    visit new_user_session_path

    fill_in "Email", with: "dana@example.com"
    fill_in "Password", with: "not-the-password"
    click_button "Log in"

    expect(page).to have_css(".dd-auth__title", text: "Log in")
    expect(page).to have_no_css(".dd-bottom-nav")
  end
end
