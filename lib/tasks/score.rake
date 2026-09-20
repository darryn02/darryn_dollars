namespace :score do
  desc 'Scrape NFL lines and create games and contests'
  task wagers: :lines do
    WagerScorer.run
  end

  task :lines => ['scrape:nfl_results', 'scrape:ncaaf_results']  do
    LineScorer.run
  end

  # For the one deploy that turns MoneylineScorer from a no-op into a real
  # scorer. Roughly 386 moneyline rows have been sitting pending since
  # before settlement existed for them, all on games long since finished, so
  # the first ordinary score:lines would grade the entire backlog in a
  # single unreviewed write - which is also the first time the new scorer
  # ever runs against real data.
  #
  # Run this instead for that pass, inspect the backlog
  # (Line.moneyline.pending.count) by hand, then go back to score:lines.
  #
  # This is a tool, not a guard: the scheduled score:lines entry will still
  # grade the backlog if it fires first, so pause it around the deploy.
  desc 'Score every pending line except moneyline - the controlled first run after the scorer lands'
  task lines_except_moneyline: :environment do
    puts LineScorer.run(Line.pending.where.not(kind: :moneyline))
  end
end
