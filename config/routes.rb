Rails.application.routes.draw do
  devise_for :users
  post 'twilio/sms'
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
  resource :account, only: [:show, :update]
  resources :users, only: [:edit, :update]

  namespace :admin do
    resource :dashboard, only: [:show] do
      member do
        get :fetch_lines
        get :fetch_scores
        get :score_lines
        get :score_wagers
      end
    end
  end

  root to: 'lines#index'
end
