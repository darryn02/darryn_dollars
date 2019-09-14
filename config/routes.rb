Rails.application.routes.draw do
  resources :games, only: [:index]
  resources :betting_slips, only: [:create, :show, :edit, :update]
end
