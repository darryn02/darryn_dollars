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
  # completed_at is a separate fact from having scores, now that scores are
  # written at half time too. Anything asserting on a full game or second half
  # result has to say the game is over.
  def create_game(sport: :nfl, starts_at: 2.hours.from_now,
                  away: nil, home: nil, completed_at: nil)
    game = Game.create!(sport: sport, starts_at: starts_at, completed_at: completed_at)
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

  # A moneyline always belongs to a side, so contestant: is required here
  # where create_total does not take one at all. odds is required too: the
  # column default of -110 is a spread price, and a moneyline that quietly
  # inherits it tests nothing this market does differently.
  #
  # value is zero because the column is NOT NULL and a moneyline carries no
  # handicap - not because zero means anything.
  def create_moneyline(game:, contestant:, odds:, scope: :game, **attrs)
    game.lines.create!(kind: :moneyline, scope: scope, value: 0, odds: odds,
                       contestant: contestant, **attrs)
  end

  # A full card: both spreads and both sides of the total.
  #
  # Moneyline is off by default. Adding it unconditionally would change the
  # shape of every board and chump-stamp spec that builds a card, so a spec
  # that wants one asks for it.
  #
  # The default pair is -150/+120, which is already above the vig floor and
  # so passes through MoneylinePricer untouched - a card built here looks
  # like one the scraper would have produced.
  def create_full_card(game:, moneyline: false)
    away, home = game.contestants.sort_by(&:priority)

    card = {
      away_spread: create_spread(game: game, contestant: away, value: 2.5),
      home_spread: create_spread(game: game, contestant: home, value: -2.5),
      over: create_total(game: game, kind: :over, value: 47.5),
      under: create_total(game: game, kind: :under, value: 47.5)
    }

    return card unless moneyline

    card.merge(
      away_moneyline: create_moneyline(game: game, contestant: away, odds: 120),
      home_moneyline: create_moneyline(game: game, contestant: home, odds: -150)
    )
  end

  def create_wager(account:, line:, amount: 100, status: :pending, bet_slip: nil)
    bet_slip ||= BetSlip.create!(account: account, status: :pending)

    Wager.create!(account: account, bet_slip: bet_slip, line: line,
                  amount: amount, status: status)
  end
end

RSpec.configure do |config|
  config.include DomainBuilders

  # MONEYLINE_ENABLED defaults to off when absent, so without this the suite
  # would inherit whatever the shell happens to have and every moneyline
  # wager would be rejected by Wager#moneyline_is_offerable. Set it
  # explicitly rather than depending on ambient config, and restore the
  # original afterwards the way spec/models/sports_spec.rb does.
  #
  # A spec that needs the switch off - the board-unchanged spec, the
  # rejection specs - overrides ENV inside its own example.
  config.around do |example|
    original = ENV.to_hash.slice("MONEYLINE_ENABLED")
    ENV["MONEYLINE_ENABLED"] = "1"
    example.run
  ensure
    ENV.delete("MONEYLINE_ENABLED")
    original.each { |key, value| ENV[key] = value }
  end
end
