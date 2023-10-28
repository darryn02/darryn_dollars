class UsersController < ApplicationController
  def edit
    if current_user.admin? && params.key?(:user_id)
      @user = User.find(params[:user_id])
    else
      @user = current_user
    end
  end

  def update
    @user = User.find(params[:id])
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

  def user_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end
end
