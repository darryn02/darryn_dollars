class LineScorer
  def self.run(scope = Line.pending)
    new.run(scope)
  end

  def run(scope)
    scope.
    includes(game: :contestants).
    references(:contestants).
    where.not(contestants: { scores: [] }).
    find_each do |line|
      scorer = LineScorerFactory.build(line).run
    end
  end
end
