module Admin
  class PaymentsController < ApplicationController
    before_action :sanitize_params

    def create
      Payment.create!(payment_params.reverse_merge(submitted_at: Time.now))
      redirect_to admin_dashboard_path
    end

    private

    def payment_params
      params.require(:payment).permit(:account_id, :amount, :submitted_at)
    end

    def sanitize_params
      params[:payment][:amount] = params[:payment][:amount].gsub(/[\$\,]/, "")
    end
  end
end
