class LineScorer
  def self.run(scope = Line.all)
    new.run(scope)
  end

  def run(scope)
    scope.
    includes(game: :contestants).
    references(:contestants).
    where.not(contestants: { scores: [] }).
    pending.
    find_each do |line|
      scorer = LineScorerFactory.build(line).run
    end
  end
end
