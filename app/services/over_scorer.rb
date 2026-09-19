class OverScorer < Scorer
  def run
    total = combined_score(line.game.contestants)

    { wins: 0, losses: 0, pushes: 0 }.tap do |results|
      if total.blank?
        line.pending!
      elsif total > line.value
        line.win!
        results[:wins] += 1
      elsif total < line.value
        line.loss!
        results[:losses] += 1
      else
        line.push!
        results[:pushes] += 1
      end
    end
  end
end
