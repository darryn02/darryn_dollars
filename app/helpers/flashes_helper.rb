module FlashesHelper
  def user_facing_flashes
    flash.to_hash.slice("alert", "error", "notice", "success").
      reject { |_, message| message.blank? }
  end
end
