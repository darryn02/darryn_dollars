require "rails_helper"
require "rake"

# The task that retires the moneyline backlog under review. Retiring it is
# what makes a gate inside LineScorer unnecessary: once these rows are not
# pending, an unscoped LineScorer.run is harmless from every caller.
RSpec.describe "score:moneyline_backlog", type: :task do
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("score:moneyline_backlog")
    Rake::Task["score:moneyline_backlog"].reenable
    ENV.delete("COMMIT")
  end

  after { ENV.delete("COMMIT") }

  def finished_game_with_moneyline(away_score:, home_score:, odds: -285)
    @seq = @seq.to_i + 1
    game = create_game(
      starts_at: 4.hours.ago, completed_at: 1.hour.ago,
      away: create_competitor(region: "Away#{@seq}", name: "Ones", abbreviation: "AW#{@seq}"),
      home: create_competitor(region: "Home#{@seq}", name: "Twos", abbreviation: "HM#{@seq}")
    )
    away, home = game.contestants.sort_by(&:priority)
    away.update!(scores: [away_score])
    home.update!(scores: [home_score])
    create_moneyline(game: game, contestant: away, odds: odds)
  end

  def run_task = Rake::Task["score:moneyline_backlog"].invoke

  it "reports what it would grade and writes nothing by default" do
    line = finished_game_with_moneyline(away_score: 24, home_score: 21)

    expect { run_task }.to output(/1 pending moneyline lines.*24-21.*win/m).to_stdout

    expect(line.reload).to be_pending
  end

  it "says how to commit, rather than leaving the operator guessing" do
    finished_game_with_moneyline(away_score: 24, home_score: 21)

    expect { run_task }.to output(/Re-run with COMMIT=1/).to_stdout
  end

  it "grades the backlog when told to commit" do
    winner = finished_game_with_moneyline(away_score: 24, home_score: 21)
    loser = finished_game_with_moneyline(away_score: 17, home_score: 20)
    ENV["COMMIT"] = "1"

    expect { run_task }.to output(/Committed/).to_stdout

    expect(winner.reload).to be_win
    expect(loser.reload).to be_loss
  end

  # After committing, nothing is left for an unscoped run to bulk-grade -
  # which is the whole point of retiring the backlog instead of gating.
  it "leaves an unscoped LineScorer run with no moneyline work to do" do
    finished_game_with_moneyline(away_score: 24, home_score: 21)
    ENV["COMMIT"] = "1"
    run_task

    expect(Line.moneyline.pending).to be_empty
    expect(LineScorer.run(Line.pending)).to eq("No updates")
  end

  # Same gate LineScorer applies. Grading these would settle a game that is
  # still being played.
  it "leaves a game that is not finished alone" do
    game = create_game(starts_at: 2.hours.ago)
    away, home = game.contestants.sort_by(&:priority)
    away.update!(scores: [7, 3])
    home.update!(scores: [0, 10])
    line = create_moneyline(game: game, contestant: away, odds: -150)
    ENV["COMMIT"] = "1"

    expect { run_task }.to output(/Nothing to retire/).to_stdout

    expect(line.reload).to be_pending
  end

  it "says so plainly when there is no backlog at all" do
    expect { run_task }.to output(/Nothing to retire/).to_stdout
  end
end
