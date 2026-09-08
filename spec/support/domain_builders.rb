# Plain ActiveRecord builders, in the style the existing specs already use.
# spec/factories.rb is FactoryGirl-era and never registered; nothing here
# touches it.
#
# The defaults are chosen to be boring and wagerable: a game two hours out sits
# inside Game.wagerable (3.hours.ago .. now + Wager::WINDOW), which is what
# makes the board render bet buttons at all.
module DomainBuilders
  module_function

  def create_user(name: "Player", email: nil, admin: false, password: "password123")
    @user_seq = @user_seq.to_i + 1

    User.create!(
      name: name,
      email: email || "player#{@user_seq}@example.com",
      mobile: "+1202555#{format('%04d', @user_seq)}",
      admin: admin,
      password: password,
      password_confirmation: password
    )
  end

  def create_account(user:, credit_limit: 5_000, initial_balance: 0, **attrs)
    user.accounts.create!(credit_limit: credit_limit, initial_balance: initial_balance, **attrs)
  end

  def create_competitor(region:, name:, abbreviation:, sport: :nfl, **attrs)
    Competitor.create!(sport: sport, region: region, name: name, abbreviation: abbreviation, **attrs)
  end

  # An NFL game with two contestants, away (priority 0) then home (priority 1),
  # scheduled inside the wagering window unless told otherwise.
  def create_game(sport: :nfl, starts_at: 2.hours.from_now,
                  away: nil, home: nil)
    game = Game.create!(sport: sport, starts_at: starts_at)
    away ||= create_competitor(region: "Buffalo", name: "Bills", abbreviation: "BUF", sport: sport)
    home ||= create_competitor(region: "Miami", name: "Dolphins", abbreviation: "MIA", sport: sport)

    game.contestants.create!(competitor: away, priority: 0)
    game.contestants.create!(competitor: home, priority: 1)
    game
  end

  def create_spread(game:, contestant:, value:, scope: :game, odds: -110, **attrs)
    game.lines.create!(kind: :point_spread, scope: scope, value: value,
                       odds: odds, contestant: contestant, **attrs)
  end

  def create_total(game:, kind:, value:, scope: :game, odds: -110, **attrs)
    game.lines.create!(kind: kind, scope: scope, value: value, odds: odds, **attrs)
  end

  # A full card: both spreads and both sides of the total.
  def create_full_card(game:)
    away, home = game.contestants.sort_by(&:priority)

    {
      away_spread: create_spread(game: game, contestant: away, value: 2.5),
      home_spread: create_spread(game: game, contestant: home, value: -2.5),
      over: create_total(game: game, kind: :over, value: 47.5),
      under: create_total(game: game, kind: :under, value: 47.5)
    }
  end

  def create_wager(account:, line:, amount: 100, status: :pending, bet_slip: nil)
    bet_slip ||= BetSlip.create!(account: account, status: :pending)

    Wager.create!(account: account, bet_slip: bet_slip, line: line,
                  amount: amount, status: status)
  end
end

RSpec.configure do |config|
  config.include DomainBuilders
end
