namespace :scrape do
  desc 'Scrape NFL lines and create games and contests'
  task nfl_lines: :environment do
    LineScraper.run
    LineScraper.run("first_half")
  end

  task nfl_second_half_lines: :environment do
    LineScraper.new.run("second_half")
  end

  task nfl_results: :environment do
    ScoreScraper.run
  end
end
