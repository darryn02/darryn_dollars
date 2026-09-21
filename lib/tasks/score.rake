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
  # Run this first so everything else settles normally, then inspect and
  # retire the backlog with score:moneyline_backlog.
  desc 'Score every pending line except moneyline - the controlled first run after the scorer lands'
  task lines_except_moneyline: :environment do
    puts LineScorer.run(Line.pending.where.not(kind: :moneyline))
  end

  # Retires the moneyline backlog under review, which is what makes a gate
  # in LineScorer unnecessary. Once these rows are no longer pending, an
  # unscoped LineScorer.run is harmless from every caller - the scheduler,
  # the admin dashboard button - permanently, with nothing to remember.
  #
  # Dry by default: it grades inside a transaction and rolls back, so the
  # report is produced by the real MoneylineScorer rather than by a second
  # implementation of the rules that could disagree with it. COMMIT=1 keeps
  # the writes.
  desc 'Report what the pending moneyline backlog would grade to; COMMIT=1 to grade it'
  task moneyline_backlog: :environment do
    commit = ENV["COMMIT"] == "1"

    # Same gate LineScorer applies: a line whose periods are not all in yet
    # is not ready, and grading it would settle a game still being played.
    lines = Line.moneyline.pending.includes(game: :contestants).select(&:settleable?)

    if lines.empty?
      puts "No pending moneyline lines are ready to settle. Nothing to retire."
      next
    end

    scoreline = lambda do |line|
      line.game.contestants.sort_by(&:priority).
        map { |contestant| contestant.scores[line.periods].to_a.sum }.join("-")
    end

    rows = []
    ActiveRecord::Base.transaction do
      lines.each do |line|
        MoneylineScorer.run(line)
        rows << [line.to_s, scoreline.call(line), line.reload.result]
      end

      raise ActiveRecord::Rollback unless commit
    end

    puts "#{rows.size} pending moneyline lines"
    puts "-" * 60
    rows.each { |label, score, result| puts format("  %-34s %-10s -> %s", label, score, result) }
    puts "-" * 60
    puts rows.group_by(&:last).map { |result, group| "#{result}: #{group.size}" }.sort.join(", ")

    if commit
      puts "\nCommitted. The backlog is retired and score:lines is safe from every caller."
    else
      puts "\nNothing was written. Re-run with COMMIT=1 to grade these."
    end
  end
end
