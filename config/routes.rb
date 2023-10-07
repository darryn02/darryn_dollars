Rails.application.routes.draw do
  post 'twilio/sms'
  resources :games, only: [:index]
  resource :bet_slip, only: [:edit, :update, :show]
  resource :account, only: [:show]
  root to: 'games#index'
end
