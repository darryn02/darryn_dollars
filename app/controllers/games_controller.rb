class GamesController < ApplicationController
  def index
    @games = Game.unplayed.includes(contests: { contestants: :lines })
  end
end
