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
      error = "Unable to update settings" if !@user.update(user_params.except(:accounts_attributes))
    else
      error = "Unable to update settings" if !@user.update_without_password(user_params.except(:accounts_attributes))
    end

    update_account_settings! if error.blank?

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
    params.require(:user).permit(:name, :password, :password_confirmation,
                                 accounts_attributes: [:id, :nickname, :leaderboard_visible])
  end

  # Looked up through @user.accounts.find_by rather than Account.find, so a
  # submitted id that does not belong to this user is simply not found and
  # skipped - not acted on. Only nickname and leaderboard_visible are ever
  # written, regardless of what else the params carry, and only the ones
  # actually present - leaderboard_visible is a not-null column, so casting a
  # missing key would write nil and raise rather than just leaving it alone.
  def update_account_settings!
    accounts_attributes = user_params[:accounts_attributes]
    return if accounts_attributes.blank?

    accounts_attributes.each_value do |attrs|
      account = @user.accounts.find_by(id: attrs[:id])
      next if account.nil?

      changes = {}
      changes[:nickname] = attrs[:nickname] if attrs.key?(:nickname)
      if attrs.key?(:leaderboard_visible)
        changes[:leaderboard_visible] = ActiveModel::Type::Boolean.new.cast(attrs[:leaderboard_visible])
      end

      account.update!(changes) if changes.any?
    end
  end
end
