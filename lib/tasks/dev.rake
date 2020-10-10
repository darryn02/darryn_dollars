if Rails.env.development? || Rails.env.test?
  require "factory_bot"

  namespace :dev do
    desc "Sample data for local development environment"
    task prime: "db:setup" do
      include FactoryGirl::Syntax::Methods

      g = Game.create(starts_at: 7.days.from_now)
      game = g.contests.create(name: 'Game', primary: true)
      game.contestants.create(competitor: Competitor.first)
      game.contestants.create(competitor: Competitor.second)
      game.contestants.first.lines.over_unders.create(value: 52)
      game.contestants.second.lines.over_unders.create(value: 52)
      game.contestants.first.lines.point_spreads.create(value: 7)
      game.contestants.second.lines.point_spreads.create(value: -7)

      halftime = g.contests.create(name: 'Halftime')
      halftime.contestants.create(competitor: Competitor.first)
      halftime.contestants.create(competitor: Competitor.second)
      halftime.contestants.first.lines.over_unders.create(value: 26)
      halftime.contestants.second.lines.over_unders.create(value: 26)
      halftime.contestants.first.lines.point_spreads.create(value: 3)
      halftime.contestants.second.lines.point_spreads.create(value: -3)
    end
  end
end
