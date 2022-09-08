Rails.application.routes.draw do
  post 'twilio/sms'
  resources :games, only: [:index]
  root to: 'games#index'
end
