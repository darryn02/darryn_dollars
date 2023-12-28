module Admin
  class PaymentsController < ApplicationController
    def create
      Payment.create!(payment_params.reverse_merge(submitted_at: Time.now))
      redirect_to admin_dashboard_path
    end

    private

    def payment_params
      params.require(:payment).permit(:account_id, :amount, :submitted_at).sanitize_params
    end

    def sanitize_params
      params[:wager][:amount] = params[:wager][:amount].gsub(/[\$\,]/, "")
    end
  end
end
