if Rails.env.development? || Rails.env.test?
  namespace :dev do
    desc "Sample data for local development environment"
    task prime: "db:setup" do
      # Built on the same DomainBuilders the specs use, so a board primed
      # here has the same shape as one a spec builds and there is one place
      # to fix when the schema moves.
      #
      # This task was dead code before, not a spreads-only seeder: it called
      # g.contests.create, an association Game has never had, plus
      # lines.over_unders and lines.point_spreads scopes that do not exist
      # and FactoryGirl::Syntax::Methods, which factory_bot no longer
      # defines. It could not run at all against this schema, so it is a
      # rewrite rather than an extension.
      require Rails.root.join("spec/support/domain_builders")
      # Called on the module rather than included: DomainBuilders is
      # module_function, and including it here would land every builder on
      # Object for the rest of the rake process.
      b = DomainBuilders

      user = b.create_user(name: "Dev Player", email: "dev@example.com")
      b.create_account(user: user, credit_limit: 5_000)

      # One ordinary card, plus a moneyline pair inside the bettable band.
      today = b.create_game(starts_at: 2.hours.from_now)
      b.create_full_card(game: today, moneyline: true)

      # A capped underdog and the favorite opposite it - the shape that
      # renders one live button and one closed cell, on about one game in
      # seven. Worth having locally, because it is easy to forget it exists.
      capped = b.create_game(
        starts_at: 3.hours.from_now,
        away: b.create_competitor(region: "Denver", name: "Broncos", abbreviation: "DEN"),
        home: b.create_competitor(region: "Kansas City", name: "Chiefs", abbreviation: "KC")
      )
      b.create_full_card(game: capped)
      away, home = capped.contestants.sort_by(&:priority)
      b.create_moneyline(game: capped, contestant: away, odds: 450)
      b.create_moneyline(game: capped, contestant: home, odds: -650)

      puts "Primed #{Game.count} games, #{Line.count} lines, #{Line.moneyline.count} of them moneyline."
      puts "MONEYLINE_ENABLED is #{Moneyline.enabled? ? "on" : "off"} - set it to 1 to see the third column."
    end
  end
end
