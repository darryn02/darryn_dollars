class AddCompletedAtToGames < ActiveRecord::Migration[7.0]
  def change
    # Scores used to be written only at the final whistle, so a contestant
    # having any scores at all meant the game was over. Now that a first half
    # settles at the half, the scores array no longer says that, and the
    # scopes that run to the end of the game - a full game line, a second half
    # that overtime can still add to - need somewhere else to read it.
    add_column :games, :completed_at, :datetime

    # Which is also why every existing score can be read as a finished game:
    # the old scraper had no other moment to write one. Without this backfill
    # a pending line on a game played before today would sit waiting on a
    # completed_at that nothing was ever going to set.
    up_only do
      execute(<<~SQL.squish)
        UPDATE games SET completed_at = games.updated_at
        WHERE EXISTS (
          SELECT 1 FROM contestants
          WHERE contestants.game_id = games.id AND contestants.scores <> '{}'
        )
      SQL
    end
  end
end
