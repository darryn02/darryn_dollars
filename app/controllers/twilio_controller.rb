class TwilioController < ApplicationController
  skip_before_action :verify_authenticity_token

  def sms
    from = params[:From]
    body = params[:Body]
    wager_components = body.split(/\n|\.\s+/).map do |str|
      WagerParser.parse(user, str)
    end

    wagers = wager_components.map do |account, game_type, line, amount, competitors|
      "$#{amount} on " \
      "#{competitors.map(&:abbreviation).join("/")} " \
      "#{line}#{game_type.present? ? " (#{game_type})" : ""}" \
      "#{" on your" + account + "account" if account.present?}"
    end

    respond body(wagers)
  rescue WagerParser::AccountNotFoundError
    respond "I'm sorry, I don't know which account you are betting under."
  rescue WagerParser::AmbiguousAccountError
    respond "I'm sorry, it wasn't clear which account you meant for each wager"
  rescue WagerParser::IncompleteWagerError => e
    respond "I'm sorry, I don't understand your wager.\n#{e.message}"
  end

  private

  def user
    @user ||= User.find_by!(mobile: params[:From])
  end

  def body(wagers)
    (["So you want to bet:"] +
    wagers +
    ["Is that right?"]).
    join("\n")
  end

  def respond(text)
    response = Twilio::TwiML::MessagingResponse.new do |r|
      r.message body: text
    end
    render xml: response.to_s
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
