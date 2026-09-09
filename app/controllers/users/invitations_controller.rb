module Users
  # devise_invitable's default authenticate_inviter! only requires being
  # signed in as the invited-to model, which here means any player could
  # invite another. This is the book's own guest list - only the admin adds
  # names to it.
  class InvitationsController < Devise::InvitationsController
    protected

    def authenticate_inviter!
      authenticate_user!(force: true)
      return current_user if current_user&.admin?

      redirect_to root_path, alert: "That part of the site is for the book only."
      nil
    end

    def invite_params
      params.require(:user).permit(:email)
    end

    def update_resource_params
      params.require(:user).permit(:invitation_token, :name, :password, :password_confirmation,
                                   :account_nickname, :account_leaderboard_visible)
    end
  end
end
