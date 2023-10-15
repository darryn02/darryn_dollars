Rails.application.routes.draw do
  devise_for :users
  post 'twilio/sms'
  resources :games, only: [:index]
  resources :lines, only: [:index]
  resources :wagers, only: [:create, :update, :destroy] do
    collection do
      get :bet_slip
      get :history
      post :confirm_pending
      delete :cancel_pending
    end
  end
  resources :bet_slips, only: [:index, :show, :update, :destroy]
  resource :leaderboard, only: [:show]
  resource :account, only: [:show]
  root to: 'lines#index'
end
