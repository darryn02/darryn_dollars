namespace :scrape do
  require 'webdrivers/chromedriver'

  desc 'Scrape NFL lines and create games and contests'
  task :nfl_lines, [:scope] => :environment do |_t, args|
    browser = Watir::Browser.new

    map = {
      'game' => 'https://www.bovada.lv/sports/football/nfl',
      'first_half' => 'https://www.bovada.lv/sports/football/nfl/first-half-lines-odd',
      'second_half' => 'https://www.bovada.lv/sports/football/nfl/second-half-lines-odd'
    }

    scope = args[:scope].presence || "game"
    url = map[scope]
    browser.goto(url)
    begin
      js_doc ||= browser.element(css: "sp-next-events div.grouped-events").wait_until(timeout: 5, &:present?)
    rescue Watir::Wait::TimeoutError
      puts "Timeout waiting for #{url}. Continuing to next page."
      next
    end
    page = Nokogiri::HTML(js_doc.inner_html)
    game_elements = page.css("section.coupon-content.more-info")

    deactivate_ids = Line.active.send(scope).pluck(:id)
    activate_ids = []

    game_elements.map do |ge|
      start_time = nil
      time_string = ge.css("sp-score-coupon.scores span.period").inner_text.strip
      time_string ||= ge.css("sp-score-coupon.scores span.empty-score").inner_text.strip
      if time_string.blank? || ["first half", "second half", "halftime"].include?(time_string.downcase)
        start_time = [(Time.now - 1.days).beginning_of_day..Time.now]
      else
        start_time = Time.strptime(time_string, "%m/%d/%y %I:%M %p")
      end

      away, home = ge.css(".competitor-name").map(&:text)
      away_team = Competitor.find_by_string!(away, sport: :nfl)
      home_team = Competitor.find_by_string!(home, sport: :nfl)

      game = Game.nfl.find_or_create_by!(starts_at: start_time, cached_competitor_ids: [away_team.id, home_team.id])
      away_contestant = game.contestants.find_or_create_by!(competitor: away_team, priority: 0)
      home_contestant = game.contestants.find_or_create_by!(competitor: home_team, priority: 1)

      away_spread, home_spread, away_ml, home_ml, total = ge.css("sp-two-way-vertical.market-type ul li").map do |line_element|
        line_element.text.strip.upcase.presence unless line_element.css('.empty-bet').present?
      end

      away_spread = away_spread&.split("(")&.first&.strip
      home_spread = home_spread&.split("(")&.first&.strip
      total = total&.gsub(/[OU]/, "")&.split("(")&.first&.strip

      away_spread, home_spread, away_ml, home_ml, total = normalize([away_spread, home_spread, away_ml, home_ml, total])

      activate_ids.push(game.lines.point_spread.send(scope).find_or_create_by!(contestant: away_contestant, value: away_spread).id) if away_spread.present?
      activate_ids.push(game.lines.point_spread.send(scope).find_or_create_by!(contestant: home_contestant, value: home_spread).id) if home_spread.present?

      activate_ids.push(game.lines.moneyline.send(scope).find_or_create_by!(contestant: away_contestant, value: 0, odds: away_ml).id) if away_ml.present?
      activate_ids.push(game.lines.moneyline.send(scope).find_or_create_by!(contestant: home_contestant, value: 0, odds: home_ml).id) if home_ml.present?

      if total.present?
        activate_ids.push(game.lines.over.send(scope).find_or_create_by!(value: total).id)
        activate_ids.push(game.lines.under.send(scope).find_or_create_by!(value: total).id)
      end

      puts "#{start_time.is_a?(Array) ? time_string : start_time.strftime("%m/%d %l:%M %p")} #{away} (#{away_spread}) @ #{home} (#{home_spread}), O/U #{total}"
    end

    Line.where(id: deactivate_ids - activate_ids).update_all(updated_at: Time.now, hidden: true)
    Line.where(id: activate_ids).update_all(updated_at: Time.now, hidden: false)
  end

  task :nfl_results do
  end

  def normalize(strings)
    Array.wrap(strings).map do |string|
      string == "EVEN" ? 0 : string
    end.then { |a| a.one? ? a.first : a }
  end
end
