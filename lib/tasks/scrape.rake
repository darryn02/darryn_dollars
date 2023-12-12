namespace :scrape do
  desc 'Scrape NFL lines and create games and contests'
  task nfl_lines: :environment do
    if ENV["USE_BOVADA_API"] == "1"
       BovadaApiClient.update_lines(sport: :nfl)
    elsif ENV["USE_ODDS_API"] == "1"
      exit unless nfl_wagerable?
      LinesApiClient.update_lines(sport: :nfl, scope: :first_half)
    else
      LineScraper.run
      LineScraper.run("first_half")
    end
  end

  task nfl_second_half_lines: :environment do
    if ENV["USE_BOVADA_API"] == "1"
      BovadaApiClient.update_lines(sport: :nfl)
    elsif ENV["USE_ODDS_API"] == "1"
      LinesApiClient.update_lines(sport: :nfl, scope: :second_half)
    else
      LineScraper.new.run("second_half")
    end
  end

  task ncaa_lines: :environment do
    LinesApiClient.update_lines(sport: :ncaaf, scope: :first_half)
  end

  task ncaa_second_half_lines: :environment do
    LinesApiClient.update_lines(sport: :ncaaf, scope: :second_half)
  end

  task nfl_results: :environment do
    exit unless Game.nfl.in_progress.exists?

    ScoreScraper.run(:nfl)
  end

  task ncaaf_results: :environment do
    exit unless Game.ncaaf.in_progress.joins(:contestants).where(contestants: { scores: [] }).exists?

    ScoreScraper.run(:ncaaf)
  end

  def nfl_wagerable?
    now = DateTime.current.in_time_zone("America/New_York").to_time

    return true if (now.thursday? || now.monday?) && now.hour.between?(17, 20)
    return true if now.sunday? && now.hour.between?(7, 20)
    # Thanksgiving or bust
    now.thursday? && now.month == 11 && ((now.day - 1) / 7 == 3)
  end
end
