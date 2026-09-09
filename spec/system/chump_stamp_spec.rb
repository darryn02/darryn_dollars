require "rails_helper"

# The money bag marks the side the chumps are loaded on. It is a read on the
# rest of the group, so it is deliberately not for the rest of the group: only
# Chad and the admins are meant to see it, and showing it to a chump would hand
# them the read they are the subject of.
#
# Both CHAD constants are read at call time, so stubbing them is enough to make
# an arbitrary record play the part.
RSpec.describe "The chump stamp", type: :system do
  let(:chad) { create_user(name: "Chad Himself") }
  let!(:chad_account) { create_account(user: chad) }

  let(:admin) { create_user(name: "The Book", admin: true) }
  let!(:admin_account) { create_account(user: admin) }

  let(:chump) { create_user(name: "Plain Player") }
  let!(:chump_account) { create_account(user: chump) }

  let(:second_chump) { create_user(name: "Another Player") }
  let!(:second_chump_account) { create_account(user: second_chump) }

  let(:game) { create_game(starts_at: 2.hours.from_now) }
  let!(:card) { create_full_card(game: game) }

  before do
    stub_const("User::CHAD", chad.id)
    stub_const("Account::CHAD", chad_account.id)

    # The crowd is on Buffalo.
    create_wager(account: chump_account, line: card[:away_spread], amount: 400)
    create_wager(account: second_chump_account, line: card[:away_spread], amount: 300)
    create_wager(account: second_chump_account, line: card[:home_spread], amount: 100)
  end

  def away_row
    find(:xpath, "//div[@class='dd-game__row'][.//span[text()='BUF']]")
  end

  def home_row
    find(:xpath, "//div[@class='dd-game__row'][.//span[text()='MIA']]")
  end

  it "is hidden from a plain player, who is the one being read" do
    login_as(chump, scope: :user)

    visit lines_path

    expect(page).to have_css(".dd-bet-btn", text: "+2.5")
    expect(page).to have_no_css(".dd-bet-btn__money")
    expect(page).to have_no_content("most money on this side")
  end

  it "is hidden from another plain player too" do
    login_as(second_chump, scope: :user)

    visit lines_path

    expect(page).to have_css(".dd-bet-btn", text: "+2.5")
    expect(page).to have_no_css(".dd-bet-btn__money")
  end

  it "shows Chad which side the money is on" do
    login_as(chad, scope: :user)

    visit lines_path

    expect(away_row).to have_css(".dd-bet-btn__money")
    expect(home_row).to have_no_css(".dd-bet-btn__money")
  end

  it "shows the admin the same read" do
    login_as(admin, scope: :user)

    visit lines_path

    expect(away_row).to have_css(".dd-bet-btn__money")
    expect(home_row).to have_no_css(".dd-bet-btn__money")
  end

  # Otherwise Chad backing a side would move the marker he is reading.
  it "does not count Chad's own money as the crowd's" do
    create_wager(account: chad_account, line: card[:home_spread], amount: 5_000)

    login_as(chad, scope: :user)

    visit lines_path

    expect(away_row).to have_css(".dd-bet-btn__money")
    expect(home_row).to have_no_css(".dd-bet-btn__money")
  end
end
