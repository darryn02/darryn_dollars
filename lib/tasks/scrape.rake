namespace :scrape do
  desc 'Scrape NFL lines and create games and contests'
  task nfl_lines: :environment do
    if ENV["USE_ODDS_API"] == "1"
      LinesApiClient.update_lines(:first_half)
    else
      LineScraper.run
      LineScraper.run("first_half")
    end
  end

  task nfl_second_half_lines: :environment do
    if ENV["USE_ODDS_API"] == "1"
      LinesApiClient.update_lines(:second_half)
    else
      LineScraper.new.run("second_half")
    end
  end

  task nfl_results: :environment do
    return unless gametime?

    ScoreScraper.run
  end

  def gametime?
    datetime = DateTime.current.in_time_zone("America/Los_Angeles")
    (datetime.thursday? && datetime.hour.between?(6,21)) ||
      (datetime.sunday? && datetime.hour.between?(7,21)) ||
      (datetime.monday? && datetime.hour.between?(6,21))
  end
end
