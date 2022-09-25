class TwilioController < ApplicationController
  skip_before_action :verify_authenticity_token
  rescue_from ActiveRecord::RecordNotFound, with: :account_not_found

  class CommandProcessor
    def self.process(user, body)
      new(user, body).process
    end

    def initialize(user, body)
      @user = user
      @body = body.to_s.squish.downcase
    end

    def process
      if body.starts_with?("lines")
        Sms::LinesPresenter.new(body.sub("lines", "")).to_s.presence || "No lines currently available. Check back 2 hours prior to scheduled event start time."
      elsif body.match(/(bets|bet slip|slip)/).present?
        format_bet_slip.presence || "You have no active wagers"
      elsif body.starts_with?("history")
        format_history.presence || "No settled bets found"
      elsif body.starts_with?("balance")
        format_account_balances
      elsif body.starts_with?("cancel")
        cancel_wager(body.sub("cancel", "").squish)
      elsif body.match(/(help|tips|usage|directions|instructions|guide|manual)/).present?
        format_help
      elsif body.starts_with?("scrape")
        scrape_lines(body.sub("scrape", "").squish)
      else
        process_wager
      end
    end

    private

    attr_reader :user, :body

    def format_bet_slip
      if user.accounts.many?
        user.accounts.each do |account|
          account.wagers.confirmed.order(placed_at: :desc).map do |wager|
            "#{account}: #{format_currency(wager.amount)} #{wager.line}"
          end.join("\n")
        end.join("\n")
      else
        user.accounts.first.wagers.confirmed.order(placed_at: :desc).map do |wager|
          "#{format_currency(wager.amount)} #{wager.line}"
        end.join("\n")
      end
    end

    def format_history
      if user.accounts.many?
        user.accounts.each do |account|
          account.wagers.historical.order(id: :desc).limit(ENV.fetch("HISTORY_SIZE", 10).to_i).map do |wager|
            "#{account}: (#{wager.status}) #{wager.placed_at.strftime("%-m/%-d")} #{format_currency(wager.amount)} #{wager.line}"
          end.join("\n")
        end.join("\n")
      else
        user.accounts.first.wagers.historical.order(id: :desc).limit(ENV.fetch("HISTORY_SIZE", 10).to_i).map do |wager|
          "(#{wager.status}) #{wager.placed_at.strftime("%-m/%-d")} #{format_currency(wager.amount)} #{wager.line}"
        end.join("\n")
      end
    end

    def cancel_wager(str)
      wager_id = Integer(str, exception: false)
      wager = Wager.joins(:account).find_by(id: wager_id, accounts: { user_id: user.id })
      if wager.nil?
        "Wager not found - check ID and try again"
      elsif wager.canceled?
        "Wager already canceled"
      elsif Time.current - wager.placed_at > Wager::GRACE_PERIOD
        "Sorry, wagers can only be canceled within #{Wager::GRACE_PERIOD / 60} minutes after being placed."
      elsif wager.historical?
        "Wager already a #{wager.status}"
      else
        wager.canceled!
        "Wager #{wager.id} canceled."
      end
    end

    def format_account_balances
      user.accounts.map do |account|
        balance = account.wagers.sum(:net)
        utilization = [(-1 * balance / account.credit_limit * 100).round, 0].max
        "#{format_currency(balance)} (Credit Limit: #{format_currency(account.credit_limit)}, #{utilization}% utilized)"

        [
          account.name if user.accounts.many?,
          "#{format_currency(account.wagers.sum(:net))}"
        ].compact.join(": ")
      end.join("\n")
    end

    def scrape_lines(args)
      if user.admin?
        LineScraper.new.run(args.presence || "game")
      else
        "Nice try. Only admins can do that."
      end
    end

    def format_help
      [
        "You can say:",
        "- lines",
        "- lines first half (or 1st half, 1h, etc)",
        "- lines second half (or 2nd half, 2h, etc)",
        "- bet slip (or simply 'slip' or 'bets')",
        "- cancel <wager ID> (only within #{Wager::GRACE_PERIOD / 60} minutes)",
        "- balance",
        "- history",
        "- usage (or tips, instructions, guide)"
      ].join("\n")
    end

    def format_currency(str)
      ActionController::Base.helpers.number_to_currency(str)
    end

    def process_wager
      body.split(/\n|\r|\.\s+/).map(&:presence).compact.map do |str|
        begin
          account, kind, scope, line, amount, competitors = WagerParser.parse(user, str)
          if scope == :second_half
            LineScraper.ensure_second_half_lines_are_recent!
          end
          wager = WagerProcessor.new.create_wager(account, kind, scope, line, amount, competitors)
        rescue WagerParser::AccountNotFoundError
          "[x]: #{str}: Account not clear."
        rescue WagerParser::AmbiguousAccountError
          "[x]: #{str}: Account ambiguous"
        rescue WagerParser::IncompleteWagerError => e
          "[x]: #{str}: Wager unclear - #{e.message}"
        rescue WagerProcessor::LineChange
          "[x]: #{str}: Line has changed"
        rescue WagerProcessor::LineNotFound
          "[x]: #{str}: Line not found"
        rescue WagerProcessor::LineExpired
          "[x]: #{str}: Line has expired"
        end
      end.join("\n")
    end
  end

  def sms
    respond CommandProcessor.process(user, params[:Body])
  end

  private

  def user
    @user ||= User.find_by!(mobile: params[:From])
  end

  def respond(text)
    response = Twilio::TwiML::MessagingResponse.new do |r|
      r.message body: text
    end
    render xml: response.to_s
  end

  def account_not_found
    respond("Number not recognized")
  end
end
=begin
 {
   "ToCountry"=>"US",
   "ToState"=>"AL",
   "SmsMessageSid"=>"SM0592fafe2bbc4070b48a9043bd199912",
   "NumMedia"=>"0",
   "ToCity"=>"",
   "FromZip"=>"02482",
   "SmsSid"=>"SM0592fafe2bbc4070b48a9043bd199912",
   "FromState"=>"MA",
   "SmsStatus"=>"received",
   "FromCity"=>"BOSTON",
   "Body"=>"Yo",
   "FromCountry"=>"US",
   "To"=>"+12059533960",
   "ToZip"=>"",
   "NumSegments"=>"1",
   "MessageSid"=>"SM0592fafe2bbc4070b48a9043bd199912",
   "AccountSid"=>"ACe4abb33c4c3ec0c6d155580d9c892560",
   "From"=>"+16179218408",
   "ApiVersion"=>"2010-04-01",
   "controller"=>"twilio",
   "action"=>"sms"
 }
=end
