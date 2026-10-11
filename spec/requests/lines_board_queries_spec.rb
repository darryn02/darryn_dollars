require "rails_helper"

# The board draws one bet sheet per line, and each sheet asks about the
# player's accounts. Asked of the association each time, that was three
# account queries per sheet - on a Saturday slate, a few hundred a page view.
RSpec.describe "Account queries on the lines board", type: :request do
  let(:player) { create_user(name: "Dana Player") }

  before { sign_in player }

  def account_queries_for_the_board
    count = 0
    counter = lambda do |*, payload|
      count += 1 if payload[:sql].include?('FROM "accounts"') && payload[:name] != "SCHEMA"
    end

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get lines_path }

    expect(response).to have_http_status(:ok)
    count
  end

  def add_a_game(away:, home:)
    game = create_game(
      starts_at: 2.hours.from_now,
      away: create_competitor(region: away, name: "#{away} Team", abbreviation: away[0, 3].upcase),
      home: create_competitor(region: home, name: "#{home} Team", abbreviation: home[0, 3].upcase)
    )
    create_full_card(game: game)
  end

  shared_examples "a board that reads the accounts once" do
    it "runs the same account queries however many lines are on the board" do
      add_a_game(away: "Dallas", home: "Denver")
      with_one_game = account_queries_for_the_board

      add_a_game(away: "Seattle", home: "Chicago")
      with_two_games = account_queries_for_the_board

      expect(response.body.scan("dd-bet-sheet").size).to be > 4
      expect(with_two_games).to eq(with_one_game)
    end
  end

  context "for a player with one account" do
    before { create_account(user: player) }

    it_behaves_like "a board that reads the accounts once"
  end

  context "for a player with two accounts" do
    before do
      create_account(user: player, name: "Big Joe")
      create_account(user: player, name: "Little Joe")
    end

    it_behaves_like "a board that reads the accounts once"
  end
end
