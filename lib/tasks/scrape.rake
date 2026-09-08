namespace :scrape do
  desc 'Fetch NFL lines, if the schedule says it is worth it'
  task nfl_lines: :environment do
    next unless ScrapeWindow.due?(sport: :nfl)

    ScrapeRun.track(sport: :nfl, scope: :game) do
      if ENV["USE_BOVADA_API"] == "1"
        BovadaApiClient.update_lines(sport: :nfl)
      elsif ENV["USE_ODDS_API"] == "1"
        LinesApiClient.update_lines(sport: :nfl, scope: :first_half)
      end
    end
  end

  task nfl_second_half_lines: :environment do
    next unless ScrapeWindow.due?(sport: :nfl)

    ScrapeRun.track(sport: :nfl, scope: :second_half) do
      if ENV["USE_BOVADA_API"] == "1"
        BovadaApiClient.update_lines(sport: :nfl)
      elsif ENV["USE_ODDS_API"] == "1"
        LinesApiClient.update_lines(sport: :nfl, scope: :second_half)
      end
    end
  end

  task ncaa_lines: :environment do
    next unless ScrapeWindow.due?(sport: :ncaaf)

    ScrapeRun.track(sport: :ncaaf, scope: :game) do
      LinesApiClient.update_lines(sport: :ncaaf, scope: :first_half)
    end
  end

  task ncaa_second_half_lines: :environment do
    next unless ScrapeWindow.due?(sport: :ncaaf)

    ScrapeRun.track(sport: :ncaaf, scope: :second_half) do
      LinesApiClient.update_lines(sport: :ncaaf, scope: :second_half)
    end
  end

  task nfl_results: :environment do
    exit unless Game.nfl.joins(:wagers).where(wagers: { status: :confirmed }).exists?

    ScoreScraper.run(:nfl)
  end

  task ncaaf_results: :environment do
    exit unless Game.ncaaf.joins(:wagers).where(wagers: { status: :confirmed }).exists?

    ScoreScraper.run(:ncaaf)
  end
end
