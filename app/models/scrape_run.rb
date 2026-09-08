# An audit trail of every attempt to fetch lines from a book.
#
# This exists because line rows alone cannot tell you whether a scrape ran.
# A run that finds no changes writes nothing, so for years the only evidence
# a fetch had happened at all was the timestamp on rows that happened to move.
class ScrapeRun < ApplicationRecord
  SUCCESS = "success".freeze
  NO_DATA = "no_data".freeze
  CHALLENGED = "challenged".freeze
  ERROR = "error".freeze

  # Outcomes that mean the book pushed back and we should ease off.
  BACKOFF_OUTCOMES = [CHALLENGED, ERROR].freeze

  scope :for_sport, ->(sport) { where(sport: sport.to_s) }
  scope :recent_first, -> { order(ran_at: :desc) }

  def self.record!(sport:, outcome:, scope: nil, **attrs)
    create!(attrs.merge(sport: sport.to_s, scope: scope&.to_s, outcome: outcome, ran_at: Time.current))
  end

  # Wraps an attempt so that every run leaves a trace, whether or not it
  # changed anything. An exception can name its own outcome by responding to
  # #scrape_outcome, which is how a challenge is distinguished from a bug.
  def self.track(sport:, scope: nil)
    yield.tap do |result|
      attrs = if result.respond_to?(:to_scrape_run_attributes)
                result.to_scrape_run_attributes
              else
                { outcome: SUCCESS, detail: result.to_s.first(500) }
              end

      record!(sport: sport, scope: scope, **attrs)
    end
  rescue StandardError => e
    outcome = e.respond_to?(:scrape_outcome) ? e.scrape_outcome : ERROR
    record!(sport: sport, scope: scope, outcome: outcome, detail: "#{e.class}: #{e.message}".first(500))
    raise
  end

  def success? = outcome == SUCCESS
  def challenged? = outcome == CHALLENGED
  def backoff? = BACKOFF_OUTCOMES.include?(outcome)
end
