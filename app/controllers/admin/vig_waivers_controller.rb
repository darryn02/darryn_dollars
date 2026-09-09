module Admin
  # Flips Wager#vig_waived - the book's price for a bet stays whatever the
  # line showed at placement, but a loss is capped at what a win would have
  # paid instead of the full stake. Works whether the wager is still pending
  # or was already settled: Wager#update_net recomputes on every save
  # regardless of why it was saved, so crediting a bet that already lost is
  # the same write as adjusting one still open.
  class VigWaiversController < ApplicationController
    before_action :require_admin!

    def new
      @games = Game.viewable.order(:starts_at)
      @lines = Line.active.includes(game: :contestants).order("games.starts_at").
        joins(:game).references(:game)
    end

    def index
      @scope_params = scope_params
      @wagers = matching_wagers.includes(:line, account: :user).order(:placed_at)
    end

    def create
      selected_ids = Array(params[:wager_ids]).map(&:to_i)

      # Re-derived from the submitted scope, not trusted from the id list
      # alone - a tampered id outside what was actually shown is simply not
      # among the candidates and gets skipped, same discipline as the rest
      # of the admin surface. One at a time and through update!, not
      # update_all, so before_save recomputes net on every wager it touches -
      # that is what lets this credit a bet that already settled.
      candidates = matching_wagers.where(id: selected_ids)
      count = candidates.count
      candidates.find_each { |wager| wager.update!(vig_waived: true) }

      redirect_to new_admin_vig_waiver_path, notice: "Waived the vig on #{count} wager(s)."
    end

    def destroy
      wager = Wager.find_by(id: params[:id])
      wager&.update!(vig_waived: false)

      redirect_back fallback_location: new_admin_vig_waiver_path, notice: "Cleared the vig waiver."
    end

    private

    def scope_params
      params.permit(:scope_type, :line_id, :game_id, :kind_group, :date).to_h.symbolize_keys
    end

    def matching_wagers
      Wager.matching_scope(**scope_params)
    end
  end
end
