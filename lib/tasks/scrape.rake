# Every line comes from Bovada. A single response carries game, first half and
# second half markets together, so the *_second_half_lines tasks now do exactly
# the same work as their siblings; they are kept only so the Heroku Scheduler
# entries pointing at them keep resolving, and can be dropped from the schedule.
namespace :scrape do
  desc 'Fetch NFL lines, if the schedule says it is worth it'
  task nfl_lines: :environment do
    next unless ScrapeWindow.due?(sport: :nfl)

    ScrapeRun.track(sport: :nfl, scope: :game) do
      BovadaApiClient.update_lines(sport: :nfl) if ENV["USE_BOVADA_API"] == "1"
    end
  end

  task nfl_second_half_lines: :environment do
    next unless ScrapeWindow.due?(sport: :nfl)

    ScrapeRun.track(sport: :nfl, scope: :second_half) do
      BovadaApiClient.update_lines(sport: :nfl) if ENV["USE_BOVADA_API"] == "1"
    end
  end

  task ncaa_lines: :environment do
    next unless ScrapeWindow.due?(sport: :ncaaf)

    ScrapeRun.track(sport: :ncaaf, scope: :game) do
      BovadaApiClient.update_lines(sport: :ncaaf) if ENV["USE_BOVADA_API"] == "1"
    end
  end

  task ncaa_second_half_lines: :environment do
    next unless ScrapeWindow.due?(sport: :ncaaf)

    ScrapeRun.track(sport: :ncaaf, scope: :second_half) do
      BovadaApiClient.update_lines(sport: :ncaaf) if ENV["USE_BOVADA_API"] == "1"
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
