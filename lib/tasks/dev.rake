if Rails.env.development? || Rails.env.test?
  require "factory_girl"

  namespace :dev do
    desc "Sample data for local development environment"
    task prime: "db:setup" do
      include FactoryGirl::Syntax::Methods

      create(:user, name: 'The Book', email: "darryn.campbell@gmaiul.com", admin: true)

      create(:competetor, name: 'Buffalo Bills')
      create(:competetor, name: 'Miami Dolphins')
      create(:competetor, name: 'New England Patriots')
      create(:competetor, name: 'New York Jets')
      create(:competetor, name: 'Baltimore Ravens')
      create(:competetor, name: 'Cincinnati Bengals')
      create(:competetor, name: 'Cleveland Browns')
      create(:competetor, name: 'Pittsburgh Steelers')
      create(:competetor, name: 'Houston Texans')
      create(:competetor, name: 'Indianapolis Colts')
      create(:competetor, name: 'Jacksonville Jaguars')
      create(:competetor, name: 'Tennessee Titans')
      create(:competetor, name: 'Denver Broncos')
      create(:competetor, name: 'Kansas City Chiefs')
      create(:competetor, name: 'Oakland Raiders')
      create(:competetor, name: 'Los Angeles Chargers')
      create(:competetor, name: 'Dallas Cowboys')
      create(:competetor, name: 'New York Giants')
      create(:competetor, name: 'Philadelphia Eagles')
      create(:competetor, name: 'Washington Redskins')
      create(:competetor, name: 'Chicago Bears')
      create(:competetor, name: 'Detroit Lions')
      create(:competetor, name: 'Green Bay Packers')
      create(:competetor, name: 'Minnesota Vikings')
      create(:competetor, name: 'Atlanta Falcons')
      create(:competetor, name: 'Carolina Panthers')
      create(:competetor, name: 'New Orleans Saints')
      create(:competetor, name: 'Tampa Bay Buccaneers')
      create(:competetor, name: 'Arizona Cardinals')
      create(:competetor, name: 'Los Angeles Rams')
      create(:competetor, name: 'San Francisco 49ers')
      create(:competetor, name: 'Seattle Seahawks')


      g = Game.create(starts_at: 7.days.from_now)
      game = g.contests.create(name: 'Game', primary: true)
      game.contestants.create(competetor: Competetor.first)
      game.contestants.create(competetor: Competetor.second)
      game.contestants.first.lines.over_unders.create(value: 52)
      game.contestants.second.lines.over_unders.create(value: 52)
      game.contestants.first.lines.point_spreads.create(value: 7)
      game.contestants.second.lines.point_spreads.create(value: -7)

      halftime = g.contests.create(name: 'Halftime')
      halftime.contestants.create(competetor: Competetor.first)
      halftime.contestants.create(competetor: Competetor.second)
      halftime.contestants.first.lines.over_unders.create(value: 26)
      halftime.contestants.second.lines.over_unders.create(value: 26)
      halftime.contestants.first.lines.point_spreads.create(value: 3)
      halftime.contestants.second.lines.point_spreads.create(value: -3)
    end
  end
end
