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
        format_lines
      elsif body.match(/(bets|bet slip|slip)/).present?
        format_bet_slip.presence || "No active wagers"
      elsif body.starts_with?("history")
        format_history.presence || "No settled bets found"
      elsif body.starts_with?("balance")
        ensure_balances_are_current!
        format_account_balances
      elsif body.starts_with?("cancel")
        cancel_wager(body.sub("cancel", "").squish)
      elsif body.match(/(help|tips|usage|directions|instructions|guide|manual)/).present?
        format_help
      elsif body.starts_with?("scrape")
        scrape_lines(body.sub("scrape", "").squish)
      elsif body.starts_with?("total")
        format_totals
      elsif body.starts_with?("action")
        format_action(body.sub("action", "").squish)
      else
        process_wager
      end
    end

    private

    attr_reader :user, :body

    def ensure_balances_are_current!
      if Wager.confirmed.where(user.accounts.where("accounts.id = wagers.account_id").arel.exists).exists?
        if Line.pending.exists?
          ScoreScraper.run
          LineScorer.run
        end
        WagerScorer.run
      end
    end

    def format_lines
      lines = Sms::LinesPresenter.new(body.sub("lines", "")).to_s
      lines.presence || "No lines currently available. Check back 2 hours prior to scheduled event start time."
    rescue => e
      "Sorry, an error occurred. Please retry, or text Darryn directly if the problem persists. (#{e.message})"
    end

    def format_bet_slip
      if user.admin?
        format_all_wagers
      else
        format_user_wagers(user)
      end
    end

    def format_all_wagers
      User.
        joins(:accounts).
        where(Wager.confirmed.where("account_id = accounts.id").arel.exists).
        distinct.
        map do |u|
        "#{u.name.split.first}:\n#{format_user_wagers(u)}"
      end.join("\n")
    end

    def format_user_wagers(usr)
      if usr.accounts.many?
        usr.accounts.map do |account|
          account.wagers.confirmed.order(placed_at: :desc).map do |wager|
            "#{account}: #{format_currency(wager.amount)} #{wager.line}"
          end.join("\n")
        end.join("\n")
      else
        usr.accounts.first.wagers.confirmed.order(placed_at: :desc).map do |wager|
          "#{format_currency(wager.amount)} #{wager.line}"
        end.join("\n")
      end
    end

    def format_history
      if user.accounts.many?
        user.accounts.map do |account|
          account.wagers.historical.order(placed_at: :desc).limit(ENV.fetch("HISTORY_SIZE", 10).to_i).map do |wager|
            "#{account}: (#{wager.status}) #{wager.placed_at.strftime("%-m/%-d")} #{format_currency(wager.amount)} #{wager.line}"
          end.join("\n")
        end.join("\n")
      else
        user.accounts.first.wagers.historical.order(placed_at: :desc).limit(ENV.fetch("HISTORY_SIZE", 10).to_i).map do |wager|
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
      user.accounts.includes(:wagers, :user).map do |account|
        utilization = [((-1 * account.balance + account.liabilities) / account.credit_limit * 100).round, 0].max
        "#{format_currency(account.balance)} (Credit Limit: #{format_currency(account.credit_limit)}, #{utilization}% utilized)"

        balance_str = [
          user.accounts.many? ? account.name : nil,
          "#{format_currency(account.balance)} with #{format_currency(account.liabilities)} in play"
        ].compact.join(": ")
        "#{balance_str} (Credit Limit: #{format_currency(account.credit_limit)}, #{utilization}% utilized)"
      end.join("\n")
    end

    def scrape_lines(args)
      if user.admin?
        LineScraper.new.run(args.presence || "game")
      else
        "Nice try. Only admins can do that."
      end
    end

    def format_totals
      if user.admin?
        total = 0
        ScoreScraper.run
        LineScorer.run
        WagerScorer.run

        Account.
          includes(:wagers, :user).
          map do |account|
          total += account.balance
          "#{account.user.name}: #{format_currency(account.balance)}"
        end.join("\n").concat(
          "\n\nTotal: #{format_currency(total)}"
        )
      else
        "Nice try. Only admins can do that."
      end
    end

    def format_action(modifier)
      if user.admin?
        Wager.confirmed.includes(line: :game).group("games.id, lines.kind, lines.scope")
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
        rescue WagerProcessor::InsufficientCredit
          "[x]: #{str}: Insufficient credit. Please make a payment."
        end
      end.join("\n")
    end
  end

  def sms
    respond CommandProcessor.process(user, params[:Body])[0..1600]
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
