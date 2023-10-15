module ApplicationHelper
  def currency(val)
    ActionController::Base.helpers.number_to_currency(val)
  end
end
