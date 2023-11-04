namespace :score do
  desc 'Scrape NFL lines and create games and contests'
  task wagers: :lines do
    WagerScorer.run
  end

  task :lines => ['scrape:nfl_results', 'scrape:ncaaf_results']  do
    LineScorer.run
  end
end
