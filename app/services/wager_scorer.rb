class WagerScorer
  def run(scope = Wager.all)
    scope.
      includes(:line).
      confirmed.
      find_each do |wager|
      if wager.line.win?
        wager.win! 
      elsif wager.line.loss?
        wager.loss! 
      elsif wager.line.push?
        wager.push! 
      end
    end
  end
end
