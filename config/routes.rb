Rails.application.routes.draw do
  post 'twilio/sms'
  resources :games, only: [:index]
  resources :betting_slips, only: [:create, :show, :edit, :update]
  root to: 'games#index'
end
