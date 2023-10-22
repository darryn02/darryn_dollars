class LineScorer
  def self.run(scope = Line.pending)
    new.run(scope)
  end

  def run(scope)
    scores = Hash.new { |h, k| h[k] = { wins: 0, losses: 0, pushes: 0 } }

    scope.
      includes(game: :contestants).
      references(:contestants).
      where.not(contestants: { scores: [] }).
      find_each do |line|
        results = LineScorerFactory.build(line).run
        scores[line.kind][:wins] += results.fetch(:wins, 0)
        scores[line.kind][:losses] += results.fetch(:losses, 0)
        scores[line.kind][:pushes] += results.fetch(:pushes, 0)
      end

    scores.each_with_object("") do |(kind, results), str|
      str += "#{kind}: #{results[:wins]} wins, #{results[:losses]} losses, #{results[:pushes]} pushes\n"
    end.presence || "No updates"
  end
end
