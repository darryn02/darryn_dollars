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

  # next, not exit. These two are prerequisites of score:lines, which is a
  # prerequisite of score:wagers, and exit tears down the whole rake process -
  # so a guard firing here took LineScorer and WagerScorer down with it and
  # the scheduled run fetched scores and settled nothing. It exited 0 while
  # doing it, so the scheduler called that a success every time.
  #
  # When the guard should fire now lives in ScoreWindow, which asks whether
  # there is anything to score and whether it could be over yet.
  task nfl_results: :environment do
    next unless ScoreWindow.due?(sport: :nfl)

    ScrapeRun.track(sport: :nfl, scope: ScrapeRun::SCORES) { ScoreScraper.run(:nfl) }
  end

  task ncaaf_results: :environment do
    next unless ScoreWindow.due?(sport: :ncaaf)

    ScrapeRun.track(sport: :ncaaf, scope: ScrapeRun::SCORES) { ScoreScraper.run(:ncaaf) }
  end
end
