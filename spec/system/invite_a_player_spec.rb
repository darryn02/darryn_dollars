require "rails_helper"

RSpec.describe "Inviting a player", type: :system do
  let(:admin) { create_user(name: "The Book", admin: true) }
  let!(:admin_account) { create_account(user: admin) }

  it "goes from the admin dashboard to a signed-in member with their own account" do
    login_as(admin, scope: :user)
    visit admin_dashboard_path
    click_link "Invite a Player"

    fill_in "Email", with: "friend@example.com"
    click_button "Invite"

    expect(page).to have_content("An invitation email has been sent")

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["friend@example.com"])

    # The mailer builds its link against the fake host in test.rb
    # (www.example.com), not Capybara's own dynamically-assigned test
    # server - visiting that literal URL would try to reach a real,
    # nonexistent server. Pull the token out and visit it through Capybara's
    # own route helper instead.
    invitation_token = mail.body.encoded[/invitation_token=([^"&\s]+)/, 1]
    expect(invitation_token).to be_present

    # A brand new browser session, with nobody signed in - exactly what the
    # actual recipient's would look like. Warden.test_reset! alone is not
    # enough here: this is a real Selenium browser with a real session
    # cookie already set from logging the admin in, and only clearing the
    # cookie actually signs it out - devise_invitable's accept page redirects
    # anyone still authenticated away with "You are already signed in."
    Warden.test_reset!
    page.driver.browser.manage.delete_all_cookies
    visit accept_user_invitation_path(invitation_token: invitation_token)

    fill_in "Name", with: "New Friend"
    fill_in "Password", with: "password123", match: :first
    fill_in "Password confirmation", with: "password123"
    fill_in "Nickname", with: "Newbie"
    check "Show me on the leaderboard"
    click_button "Join"

    expect(page).to have_css(".dd-page-title", text: "Lines")

    player = User.find_by(email: "friend@example.com")
    expect(player.name).to eq("New Friend")
    expect(player.accounts.count).to eq(1)
    expect(player.accounts.first.nickname).to eq("Newbie")
    expect(player.accounts.first.leaderboard_visible).to be(true)
  end

  it "turns a plain player away, even hitting the URL directly" do
    player = create_user(name: "Plain Player")
    create_account(user: player)
    login_as(player, scope: :user)

    visit new_user_invitation_path

    expect(page).to have_content("That part of the site is for the book only.")
    expect(page).to have_no_field("Email")
  end
end
