class LineScraper
  def self.run(scope = 'game')
    new.run(scope)
  end

  def self.ensure_second_half_lines_are_recent!
    last_update = Line.active.maximum(:updated_at)
    if last_update > 1.minute.ago
      run("second_half")
    end
  end

  def run(scope = 'game')
    require 'webdrivers/chromedriver'
    browser = Watir::Browser.new

    map = {
      'game' => 'https://www.bovada.lv/sports/football/nfl',
      'first_half' => 'https://www.bovada.lv/sports/football/nfl/first-half-lines-odd',
      'second_half' => 'https://www.bovada.lv/sports/football/nfl/second-half-lines-odd'
    }

    scope = "first_half" if scope.to_s.downcase == "1h"
    scope = "second_half" if scope.to_s.downcase == "2h"
    url = map[scope]
    browser.goto(url)
    js_doc ||= browser.element(css: "sp-next-events div.grouped-events").wait_until(timeout: 5, &:present?)
    page = Nokogiri::HTML(js_doc.inner_html)
    game_elements = page.css("section.coupon-content.more-info")

    deactivate_ids = Line.active.send(scope).pluck(:id)
    activate_ids = []

    game_elements.map do |ge|
      start_time = nil
      time_string = ge.css("sp-score-coupon.scores span.period").inner_text.strip
      time_string ||= ge.css("sp-score-coupon.scores span.empty-score").inner_text.strip
      # sp-happening-now div.grouped-events span.period time.clock
      # sp-happening-now div.grouped-events span.period span.gsub

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

      Rails.logger.info "#{start_time.is_a?(Array) ? time_string : start_time.strftime("%m/%d %l:%M %p")} #{away} (#{away_spread}) @ #{home} (#{home_spread}), O/U #{total}"
    end

    deactivated_count = Line.where(id: deactivate_ids - activate_ids).update_all(updated_at: Time.now, hidden: true)
    activated_count = Line.where(id: activate_ids).update_all(updated_at: Time.now, hidden: false)
    "#{deactivated_count} lines deactivated. #{activated_count} lines activated."

  rescue Watir::Wait::TimeoutError
    "Timeout waiting for #{url}".tap do |err|
      Rails.logger.warn err
    end
  ensure
    browser.close
  end

  private

  def normalize(strings)
    Array.wrap(strings).map do |string|
      string == "EVEN" ? 0 : string
    end.then { |a| a.one? ? a.first : a }
  end
end
