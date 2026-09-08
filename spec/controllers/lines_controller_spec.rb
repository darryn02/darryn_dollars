require "rails_helper"

# Controller specs rather than request specs on purpose: these assert which
# sport the board resolved to, and rendering the layout would drag the asset
# pipeline into every run for no extra coverage.
RSpec.describe LinesController, type: :controller do
  let(:user) do
    User.create!(name: "Player", email: "player@example.com", mobile: "+12025550100",
                 password: "password123", password_confirmation: "password123")
  end

  around do |example|
    original = ENV["NCAAF_ENABLED"]
    example.run
  ensure
    ENV.delete("NCAAF_ENABLED")
    ENV["NCAAF_ENABLED"] = original if original
  end

  before do
    user.accounts.create!(credit_limit: 1_000, initial_balance: 0)
    sign_in user
  end

  def resolved_sport(params = {})
    get :index, params: params
    controller.instance_variable_get(:@sport)
  end

  context "with every sport switched on" do
    it "defaults to the NFL board" do
      expect(resolved_sport).to eq(:nfl)
    end

    it "serves the college board when asked for it" do
      expect(resolved_sport(sport: "ncaaf")).to eq(:ncaaf)
    end
  end

  context "with NCAAF switched off" do
    before { ENV["NCAAF_ENABLED"] = "0" }

    # Hiding the pill is not a kill switch on its own - a bookmark or a link in
    # the group chat would walk straight back onto the closed board.
    it "falls back to NFL when the college board is asked for by hand" do
      expect(resolved_sport(sport: "ncaaf")).to eq(:nfl)
    end

    it "still defaults to NFL" do
      expect(resolved_sport).to eq(:nfl)
    end
  end

  context "with NFL switched off instead" do
    before { ENV["NFL_ENABLED"] = "0" }
    after { ENV.delete("NFL_ENABLED") }

    it "makes the college board the default" do
      expect(resolved_sport).to eq(:ncaaf)
    end
  end

  it "ignores a sport the board does not carry" do
    expect(resolved_sport(sport: "nba")).to eq(:nfl)
  end
end
