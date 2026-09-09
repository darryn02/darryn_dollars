class UsersController < ApplicationController
  def edit
    if current_user.admin? && params.key?(:user_id)
      @user = User.find(params[:user_id])
    else
      @user = current_user
    end
  end

  def update
    @user = User.find_by(id: params[:id])
    return deny!("You can only change your own settings.") unless editable_user?(@user)

    error = nil
    if user_params[:password].present?
      error = "Unable to update settings" if !@user.update(user_params)
    else
      error = "Unable to update settings" if !@user.update_without_password(user_params)
    end

    if error.blank?
      redirect_to edit_user_path(@user), notice: "Settings updated."
    else
      flash.now[:error] = error
      render :edit
    end
  end

  private

  # Anyone could name anybody's id here, and the password branch below sets a
  # new password without asking for the old one - so this was a way to take
  # over another player's account.
  def editable_user?(user)
    user.present? && (user == current_user || current_user.admin?)
  end

  def user_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end
end
