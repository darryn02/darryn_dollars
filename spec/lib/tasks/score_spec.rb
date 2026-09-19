require "rails_helper"
require "rake"
require "open-uri"

# The scheduled entry point, tested at the level the bug actually lived at.
#
# score:wagers depends on score:lines, which depends on both results tasks.
# Those tasks used `exit` to skip themselves, which does not skip a task - it
# tears down the whole rake process. So a guard firing in a prerequisite took
# LineScorer and WagerScorer with it, and the scheduled run fetched scores and
# settled nothing, exiting 0 while it did.
RSpec.describe "score:wagers" do
  before(:all) do
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    Rake.application.rake_require("tasks/scrape", [Rails.root.join("lib").to_s])
    Rake.application.rake_require("tasks/score", [Rails.root.join("lib").to_s])
  end

  after(:all) { Rake.application = nil }

  before do
    Rake::Task.tasks.each(&:reenable)
    allow(ScoreScraper).to receive(:run).and_return("scores fetched")
    allow(LineScorer).to receive(:run).and_return("lines scored")
    allow(WagerScorer).to receive(:run).and_return("wagers scored")
  end

  # Every example goes through this rather than invoking directly. A task that
  # calls exit kills the rspec process mid-run, which rspec reports as a short
  # green suite exiting 0 - the same silent success the bug produced in
  # production. Turning it into an ordinary failure is what makes these specs
  # a guard rather than a decoration.
  def run_task
    Rake::Task["score:wagers"].invoke
  rescue SystemExit => e
    raise "score:wagers exited the process (status #{e.status}) instead of skipping one task"
  end

  def window(nfl:, ncaaf:)
    allow(ScoreWindow).to receive(:due?).with(sport: :nfl).and_return(nfl)
    allow(ScoreWindow).to receive(:due?).with(sport: :ncaaf).and_return(ncaaf)
  end

  # The reported bug, exactly: one sport worth fetching, one not. College
  # games settle on Saturday night, so by Sunday this is the ordinary case.
  it "still scores the wagers when only one sport has anything to fetch" do
    window(nfl: true, ncaaf: false)

    run_task

    expect(ScoreScraper).to have_received(:run).with(:nfl)
    expect(LineScorer).to have_received(:run)
    expect(WagerScorer).to have_received(:run)
  end

  it "scores the wagers when neither sport is worth fetching" do
    window(nfl: false, ncaaf: false)

    run_task

    expect(ScoreScraper).not_to have_received(:run)
    expect(WagerScorer).to have_received(:run)
  end

  it "fetches both sports when both are due" do
    window(nfl: true, ncaaf: true)

    run_task

    expect(ScoreScraper).to have_received(:run).with(:nfl)
    expect(ScoreScraper).to have_received(:run).with(:ncaaf)
    expect(WagerScorer).to have_received(:run)
  end

  it "leaves a scrape_run behind for each fetch, so the cadence has something to read" do
    window(nfl: true, ncaaf: false)

    expect { run_task }.to change(ScrapeRun, :count).by(1)

    run = ScrapeRun.last
    expect(run.scope).to eq(ScrapeRun::SCORES)
    expect(run.sport).to eq("nfl")
    expect(run.outcome).to eq(ScrapeRun::SUCCESS)
  end

  it "records an ESPN failure as a score run rather than a line one" do
    window(nfl: true, ncaaf: false)
    allow(ScoreScraper).to receive(:run).and_raise(OpenURI::HTTPError.new("400 Bad Request", nil))

    expect { run_task }.to raise_error(OpenURI::HTTPError)

    expect(ScrapeRun.last.outcome).to eq(ScrapeRun::ERROR)
    expect(ScrapeRun.for_lines).to be_empty
  end
end
