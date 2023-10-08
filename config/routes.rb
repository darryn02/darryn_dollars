Rails.application.routes.draw do
  devise_for :users
  post 'twilio/sms'
  resources :games, only: [:index]
  resources :bet_slips, only: [:index, :new, :create, :show]
  resource :account, only: [:show]
  root to: 'games#index'
end
