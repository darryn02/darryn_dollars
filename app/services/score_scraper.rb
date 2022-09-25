class ScoreScraper
  def self.run(week = nil)
    new.run(week)
  end

  def run(week = nil)
    week = ((DateTime.current - DateTime.new(2022, 9, 8)) / 7.0).ceil if week.nil?

    require 'webdrivers/chromedriver'
    browser = Watir::Browser.new

    url = "https://www.espn.com/nfl/scoreboard/_/week/#{week}/year/2022/seasontype/2"

    browser.goto(url)

    js_doc ||= browser.element(css: "div.PageLayout__Main").wait_until(timeout: 5, &:present?)
    page = Nokogiri::HTML(js_doc.inner_html)
    game_modules = page.css("section.gameModules")    

    game_modules.each do |game_module|

      date_str = game_module.css("header .Card__Header__Title").inner_text
      date = Date.parse(date_str)

      game_module.css("div.ScoreboardScoreCell").each do |game|
        next unless game.css(".ScoreboardScoreCell__Time").inner_text.to_s.downcase.starts_with?("final")

        game.css("ul.ScoreboardScoreCell__Competitors li").map do |competitor_element|
          team = competitor_element.css(".ScoreCell__TeamName").inner_text
          scores = competitor_element.css(".ScoreboardScoreCell_Linescores .ScoreboardScoreCell__Value").map(&:inner_text).map(&:to_i)
          competitor = Competitor.find_by_string(team)
          contestant = Contestant.joins(:game).where(competitor: competitor).where("date_trunc('day', games.starts_at) = ?", date).first
          if scores.present? && contestant.present?
            contestant.update!(scores: scores)
          else
            Rails.logger.warn("Couldn't find #{scores.present? ? "contestant" : "scores"} for #{team} on #{date_str}")
          end
        end
      end      
    end
  end
end
