class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :authenticate_user!

  private

  # Whether the signed-in user is allowed to act on an account. Admins run the
  # book and reach all of them; everyone else reaches their own.
  def reachable_account?(account_id)
    current_user.admin? || current_user.account_ids.include?(account_id)
  end

  def require_admin!
    deny!("That part of the site is for the book only.") unless current_user&.admin?
  end

  # A refusal is a dead end, not a detour: send them back to the board with a
  # word about it rather than leaving them on a page they cannot use. HTML is
  # declared first so a request that will take anything gets the redirect
  # rather than a body of JavaScript.
  def deny!(message = "You do not have access to that.")
    @error = message

    respond_to do |format|
      format.html { redirect_to root_path, alert: message }
      format.js { render template: "application/denied", status: :forbidden }
      format.any { redirect_to root_path, alert: message }
    end
  end
end
