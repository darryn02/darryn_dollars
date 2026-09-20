# A moneyline is a spread of zero: the side with more points wins, and a tie
# pushes. Ties are not exotic here - second half scopes end level often.
class MoneylineScorer < PointSpreadScorer
  # PointSpreadScorer returns nil when the line's contestant does not match
  # either side of the game, which LineScorer#run then calls .fetch on -
  # aborting settlement for every pending line of every kind, not just this
  # one. A moneyline can reach that state without anyone doing anything
  # wrong: the contestant FK nullifies on delete.
  #
  # Grade the orphan as nothing and let the rest of the run finish. The row
  # stays pending and the logged error is what says to look at it.
  def run
    super || { wins: 0, losses: 0, pushes: 0 }
  end

  private

  def margin_threshold
    0
  end
end
