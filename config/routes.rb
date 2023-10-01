Rails.application.routes.draw do
  post 'twilio/sms'
  resources :games, only: [:index]
  resources :bet_slip, only: [:new, :create, :show]
  resource :history
  root to: 'games#index'
end
