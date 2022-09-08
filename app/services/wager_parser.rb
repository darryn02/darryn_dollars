class WagerParser
  class AccountNotFoundError < StandardError; end
  class AmbiguousAccountError < StandardError; end
  class IncompleteWagerError < StandardError; end

  def self.parse(user, wager_string)
    WagerParser.new.parse(user, wager_string)
  end

  def parse(user, remaining_string)
    account, remaining_string = extract_account(user, remaining_string)
    amount, remaining_string = extract_amount(remaining_string)
    scope, remaining_string = extract_scope(remaining_string)
    kind, line, remaining_string = extract_line(remaining_string)
    competitors, remaining_string = extract_competitors(remaining_string)
    error_if_incomplete(competitors)

    [account, kind, scope, line, amount, competitors]
  end

  private

  def extract_account(user, str)
    return [user.accounts.first, str] if user.accounts.size <= 1

    matches = match_account(user, str)
    raise AccountNotFoundError.new if matches.blank?
    raise AmbiguousAccountError.new if matches.many?
    [matches.first.first, str.sub(matches.first.last.to_s, "")]
  end

  def match_account(user, str)
    user.
      accounts.
      map { |a| [a, str.match(/^\W*#{[a.name, a.nickname].join("|")}/i)] }.
      compact.
      reject { |k,v| v.blank? }
  end

  def account_names
    user.accounts.map { |a| [a.name, a.nickname] }.map(&:downcase)
  end

  def extract_scope(str)
    types = ["1st half", "first half", "1 half", "1h", "2nd half", "second half", "2half", "2 half", "2h", "halftime"]
    scope = str.match(/(#{types.join("|")})/i)&.captures&.first.to_s
    [parsed_scope(scope), str.sub(scope, "")]
  end

  def parsed_scope(raw_scope)
    if ["1st half", "first half", "1 half", "1 half", "1h"].include?(raw_scope)
      :first_half
    elsif ["2nd half", "second half", "2half", "2 half", "2h", "halftime"].include?(raw_scope)
      :second_half
    else
      :game
    end
  end

  def extract_line(str)
    match = str.match(/(?<over>o|over)?(?<under>u|under)?\s*(?<value>(\-|\+)?[\d\.]+)\b/i)
    if match.nil?
      return [:point_spread, "", str]
    end

    line = Float(match[:value], exception: false)

    kind = nil
    if match[:under].present?
      kind = :under
    elsif match[:over].present?
      kind = :over
    elsif line.present? && line.abs >= 100
      kind = :moneyline
    else
      kind = :point_spread
    end

    [kind, line, str.sub(match.to_s, "")]
  end

  def extract_amount(str)
    match = str.match(/\$(?<amount>\d+(\.\d+)?)/)
    if match.nil? || Float(match[:amount], exception: false).nil?
      raise IncompleteWagerError.new("The amount of the wager wasn't clear.")
    end
    [match[:amount].to_f, str.sub(match.to_s, "")]
  end

  def extract_competitors(str)
    tokens = str.scan(/\w+/)
    permutations = consecutive_permutations(tokens)
    competitors = competitors_for_strings(permutations).to_a
    [competitors, tokens.each_with_object(str) { |t, str| str.sub(t, "") }]
  end

  def consecutive_permutations(tokens)
    tokens.each_with_object([]).with_index do |(token, obj), i|
      (i..tokens.count - 1).each do |j|
        obj << tokens[i..j].join(" ").downcase
      end
    end
  end

  def competitors_for_strings(permutations)
    Competitor.where("nicknames && ARRAY[?]::citext[]", permutations).or(
      Competitor.where(name: permutations)
    ).or(
      Competitor.where(full_name: permutations)
    ).or(
      Competitor.where(region: permutations)
    ).or(
      Competitor.where(abbreviation: permutations)
    ).distinct
  end

  def error_if_incomplete(competitors)
    raise IncompleteWagerError.new("The competitor was not clear.") if competitors.blank?
  end
end

