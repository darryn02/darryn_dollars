class GamesController < ApplicationController
  def index
    @games = Game.
      #wagerable.
      includes(lines: :competitor).
      order(starts_at: :asc)
  end
end
