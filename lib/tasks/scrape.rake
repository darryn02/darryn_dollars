namespace :scrape do
  desc 'Scrape NFL lines and create games and contests'
  task :nfl_lines do
    browser=Watir::Browser.new
    browser.goto('https://www.bovada.lv/sports/football/nfl')
    js_doc = browser.element(css: "div.grouped-events").wait_until(&:present?)
    page = Nokogiri::HTML(js_doc.inner_html)
    game_elements = page.css("section.coupon-content.more-info")

    game_elements.map do |ge|
      start_time = Time.strptime(ge.css("sp-score-coupon.scores span.period").inner_text.strip, "%m/%d/%y %I:%M %p")

      away, home = ge.css(".competitor-name").map(&:text)
      away_spread, home_spread, away_ml, home_ml, away_total, home_total = ge.css("sp-outcome").map(&:text)

      away_spread = away_spread&.split("(")&.first&.strip
      home_spread = home_spread&.split("(")&.first&.strip
      away_total = away_total&.gsub(/[OU]/, "")&.split("(")&.first&.strip
      home_total = home_total&.gsub(/[OU]/, "")&.split("(")&.first&.strip

      puts "#{start_time.strftime("%m/%d %l:%M %p")} #{away} (#{away_spread}) @ #{home} (#{home_spread}), O/U #{away_total}"
    end
  end

  task :nfl_results do
  end
end
