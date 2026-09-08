# What a line fetch actually did. Doubles as the flash message on the admin
# dashboard, which is why #to_s is the human sentence.
ScrapeResult = Struct.new(:outcome, :message, :created, :activated, :deactivated, :http_status, :content_type,
                          keyword_init: true) do
  def to_s = message.to_s

  def to_scrape_run_attributes
    {
      outcome: outcome,
      detail: message.to_s.first(500),
      lines_created: created.to_i,
      lines_activated: activated.to_i,
      lines_deactivated: deactivated.to_i,
      http_status: http_status,
      content_type: content_type
    }
  end
end
