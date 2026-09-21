class BetSlipsController < ApplicationController
  before_action :load_reachable_bet_slip, only: [:update, :destroy]

  def index
  end

  def new
  end

  def create
  end

  def show
  end

  # Confirming used to be a bare loop with no rescue, so a single wager the
  # book will not take - the kill switch flipped while a slip sat open, a
  # moneyline whose price moved - raised out of the loop and 500'd the whole
  # slip.
  #
  # A bare rescue is not enough either, and is arguably worse: it would leave
  # @bet_slip.confirmed! and the unconditional success flash intact, telling
  # the player a rejected wager succeeded while it sits pending, outside
  # Account#liabilities, settling nothing. So collect the failures, leave the
  # slip pending if there were any, and say which wagers did not go through.
  def update
    unless @bet_slip.pending?
      return redirect_to bet_slip_wagers_path, error: "Confirmed wagers cannot be cancelled."
    end

    # Pending only. A slip can now sit part-confirmed - one wager the book
    # would not take leaves the rest confirmed and the slip open - and
    # re-running this over every wager would put a settled one back to
    # `confirmed`. That skips `confirming?`, so no validation runs and
    # update_net rewrites net to zero, erasing a recorded loss.
    confirmed = 0
    errors = @bet_slip.wagers.pending.filter_map do |wager|
      begin
        wager.confirmed!
        confirmed += 1
        nil
      rescue ActiveRecord::RecordInvalid => e
        "#{wager}: #{e.message.sub("Validation failed:", "").strip}"
      end
    end

    if errors.empty?
      @bet_slip.confirmed!
      redirect_to bet_slip_wagers_path, notice: "Your wagers have been confirmed!"
    else
      # `confirmed` counts what this attempt moved, not what is confirmed on
      # the slip - retrying a slip that accepted nothing new used to report
      # the standing total and read as success.
      redirect_to bet_slip_wagers_path,
                  alert: (["#{confirmed} wager(s) confirmed, #{errors.size} could not be:"] +
                          errors).join("<br>").html_safe
    end
  end

  def destroy
    if @bet_slip.pending?
      # Pending only, for the same reason update is: a part-confirmed slip
      # is now reachable, and destroy_all over the whole slip would delete
      # wagers the book has already accepted - money out of the ledger with
      # no record that it was ever there.
      cancelled = @bet_slip.wagers.pending.destroy_all.size
      redirect_to bet_slip_wagers_path, notice: "#{cancelled} wager(s) cancelled"
    else
      redirect_to bet_slip_wagers_path, notice: "Confirmed wagers cannot be cancelled."
    end
  end

  private

  def load_reachable_bet_slip
    @bet_slip = BetSlip.find_by(id: params[:id])

    deny!("That bet slip is not yours.") unless @bet_slip && reachable_account?(@bet_slip.account_id)
  end
end
