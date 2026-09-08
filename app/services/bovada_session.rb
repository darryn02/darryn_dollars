require "net/http"

# One short-lived browsing session against Bovada.
#
# The app used to send a single hand-picked cookie, frozen in a config var,
# on every request forever, and throw away every cookie Bovada handed back.
# Bovada sits behind F5 BIG-IP ASM, which issues a TS<hex> session cookie and
# attaches its enforcement decisions to the session it identifies. A pinned,
# never-refreshed identity accrues suspicion until it gets challenged - which
# is why editing the cookie to anything at all restored service, and why an
# old value worked again weeks later once its session had aged out.
#
# So: no pinned cookie. Each run warms a session the way a browser does, keeps
# the cookies for the handful of requests it makes, and throws them away.
class BovadaSession
  class Challenged < StandardError
    def scrape_outcome = ScrapeRun::CHALLENGED
  end

  HOME_PAGE = "https://www.bovada.lv/sports/football/nfl".freeze

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  # Deliberately not "Ruby". Note the absence of Accept-Encoding: Net::HTTP
  # sets its own and transparently decompresses only when it does, so setting
  # it here would hand us a gzip blob to parse.
  BROWSER_HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                    "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
    "Accept" => "application/json, text/plain, */*",
    "Accept-Language" => "en-US,en;q=0.9",
    "Sec-Fetch-Dest" => "empty",
    "Sec-Fetch-Mode" => "cors",
    "Sec-Fetch-Site" => "same-origin"
  }.freeze

  def initialize
    @cookies = {}
  end

  # Fetches the league page first so we are carrying a session Bovada issued,
  # and so the JSON request has a Referer - which a real browser always sends
  # for this endpoint and the old client never did.
  def warm!
    get(HOME_PAGE, accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
    self
  rescue Challenged
    # A blocked home page is not fatal on its own; the API call is the one
    # that matters and it will raise for itself.
    self
  end

  def get_json(url)
    response = get(url, referer: HOME_PAGE)
    content_type = response["content-type"].to_s

    unless content_type.include?("json")
      raise Challenged, "expected json, got #{content_type.presence || 'nothing'} (#{response.code})"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise Challenged, "unparseable body: #{e.message.first(120)}"
  end

  private

  attr_reader :cookies

  def get(url, referer: nil, accept: nil)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    BROWSER_HEADERS.each { |k, v| request[k] = v }
    request["Accept"] = accept if accept
    request["Referer"] = referer if referer
    request["Cookie"] = cookie_header if cookies.any?

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end

    remember_cookies(response)
    raise Challenged, "HTTP #{response.code} for #{uri.path}" unless response.is_a?(Net::HTTPSuccess)

    response
  rescue Challenged
    raise
  rescue StandardError => e
    raise Challenged, "#{e.class}: #{e.message}"
  end

  def remember_cookies(response)
    response.get_fields("set-cookie").to_a.each do |raw|
      name, value = raw.split(";").first.to_s.split("=", 2)
      cookies[name.strip] = value if name.present? && value.present?
    end
  end

  def cookie_header = cookies.map { |k, v| "#{k}=#{v}" }.join("; ")
end
