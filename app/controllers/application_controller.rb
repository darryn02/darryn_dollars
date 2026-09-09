class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :track_last_seen!

  private

  # Devise's own last_sign_in_at only moves at login, and sessions here last
  # up to six months (timeout_in), so it stops meaning "was here recently"
  # within days of someone signing in. This is the site's own answer to "when
  # did they last actually show up" - stamped on every authenticated request,
  # not just a login.
  #
  # update_column skips validations and callbacks and, unlike update or touch,
  # does not bump updated_at - so this never touches the record Devise itself
  # is tracking. Throttled so a page full of AJAX polling doesn't turn into a
  # write per request; five minutes is plenty of resolution for "how long ago
  # was this person in the app", which is all it's used for.
  LAST_SEEN_RESOLUTION = 5.minutes

  def track_last_seen!
    return unless current_user
    return if current_user.last_seen_at && current_user.last_seen_at > LAST_SEEN_RESOLUTION.ago

    current_user.update_column(:last_seen_at, Time.current)
  end

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
