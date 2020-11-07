class WagerParser
  class AccountNotFoundError < StandardError; end
  class AmbiguousAccountError < StandardError; end
  class IncompleteWagerError < StandardError; end

  def self.parse(user, wager_string)
    WagerParser.new.parse(user, wager_string)
  end

  def parse(user, remaining_string)
    account, remaining_string = extract_account(user, remaining_string)
    game_type, remaining_string = extract_game_type(remaining_string)
    line, remaining_string = extract_line(remaining_string)
    amount, remaining_string = extract_amount(remaining_string)
    competitors, remaining_string = extract_competitors(remaining_string)
    error_if_incomplete(amount, competitors)

    [account, game_type, line, amount, competitors]
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

  def extract_game_type(str)
    types = ["1st half", "first half", "1 half", "1 half", "2nd half", "second half", "2half", "2 half", "halftime"]
    game_type = str.match(/(#{types.join("|")})/)&.captures&.first.to_s
    [parsed_game_type(game_type), str.sub(game_type, "")]
  end

  def parsed_game_type(raw_game_type)
    if ["1st half", "first half", "1 half", "1 half"].include?(raw_game_type)
      "first half"
    elsif ["2nd half", "second half", "2half", "2 half", "halftime"].include?(raw_game_type)
      "second half"
    end
  end

  def extract_line(str)
    line = str.match(/((over|under|\-|\+)\s*[\d\.]+)\b/)&.captures&.first.to_s
    [line, str.sub(line, "")]
  end

  def extract_amount(str)
    amount = str.match(/^[^0-9\$]*[\$]?([0-9]+)[^0-9]*$/)&.captures&.first.to_s
    [amount, str.sub(amount, "")]
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

  def error_if_incomplete(amount, competitors)
    message = nil
    if amount.blank?
      message = "The amount of the wager wasn't clear."
    elsif competitors.blank?
      message = "The competitor was not clear."
    end
    raise IncompleteWagerError.new(message) if message.present?
  end
end

