require 'rails_helper'

RSpec.describe Game, type: :model do
  describe "#wagerable? and .wagerable" do
    it "agree at the near edge, just inside 3 hours after kickoff" do
      game = create_game(starts_at: 2.hours.ago - 59.minutes)

      expect(game.wagerable?).to be(true)
      expect(Game.wagerable).to include(game)
    end

    it "agree once a game is more than 3 hours old" do
      game = create_game(starts_at: 4.hours.ago)

      expect(game.wagerable?).to be(false)
      expect(Game.wagerable).not_to include(game)
    end

    it "agree at the far edge, just inside the wager window" do
      game = create_game(starts_at: Time.current + Wager::WINDOW - 1.minute)

      expect(game.wagerable?).to be(true)
      expect(Game.wagerable).to include(game)
    end

    it "agree once a game is beyond the wager window" do
      game = create_game(starts_at: Time.current + Wager::WINDOW + 1.hour)

      expect(game.wagerable?).to be(false)
      expect(Game.wagerable).not_to include(game)
    end
  end

  describe ".viewable" do
    it "reaches out to six days from now" do
      game = create_game(starts_at: 5.days.from_now)

      expect(Game.viewable).to include(game)
    end

    it "excludes a game more than six days out" do
      game = create_game(starts_at: 7.days.from_now)

      expect(Game.viewable).not_to include(game)
    end
  end

  describe "#matchup and #short_matchup" do
    it "joins two competitors with 'vs.' and their abbreviations with a slash" do
      game = create_game(
        away: create_competitor(region: "Buffalo", name: "Bills", abbreviation: "BUF"),
        home: create_competitor(region: "Miami", name: "Dolphins", abbreviation: "MIA")
      )

      expect(game.matchup).to eq("Bills vs. Dolphins")
      expect(game.short_matchup).to eq("BUF/MIA")
    end

    it "joins more than two competitors with commas instead" do
      game = Game.create!(sport: :nfl, starts_at: 2.hours.from_now)
      %w[Bills Dolphins Jets].each_with_index do |name, i|
        competitor = create_competitor(region: name, name: name, abbreviation: name[0, 3].upcase)
        game.contestants.create!(competitor: competitor, priority: i)
      end

      expect(game.matchup).to eq("Bills,Dolphins,Jets")
    end
  end

  describe "#espn_date" do
    it "rolls a Sunday night UTC kickoff back to the Eastern calendar date" do
      # 2024-01-01 01:00 UTC is 2023-12-31 20:00 Eastern.
      game = create_game(starts_at: Time.utc(2024, 1, 1, 1, 0, 0))

      expect(game.espn_date).to eq(Date.new(2023, 12, 31))
    end
  end

  describe "#second_half_started?" do
    it "raises Unavailable when ESPN has no event matching this game" do
      game = create_game(starts_at: 2.hours.ago)

      allow(EspnScoreboard).to receive(:for).and_return(instance_double(EspnScoreboard, status_for: nil))

      expect { game.second_half_started? }.to raise_error(EspnScoreboard::Unavailable)
    end

    it "asks the matched event whether the second half has started" do
      game = create_game(starts_at: 2.hours.ago)
      status = instance_double(EspnScoreboard::Status, second_half_started?: true)

      allow(EspnScoreboard).to receive(:for).and_return(instance_double(EspnScoreboard, status_for: status))

      expect(game.second_half_started?).to be(true)
    end
  end
end
