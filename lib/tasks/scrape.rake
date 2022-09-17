namespace :scrape do
  desc 'Scrape NFL lines and create games and contests'
  task nfl_lines: :environment do
    LineScraper.new.run
    LineScraper.new.run("first_half")
  end

  task nfl_second_half_lines: :environment do
    LineScraper.new.run("second_half")
  end

  task :nfl_results do
  end
end
