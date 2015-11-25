Rails.application.routes.draw do
  root to: "users#show"

  get '/sign_in', to: 'users#sign_in', as: :sign_in
  post '/sign_in', to: 'users#sign_in!'
  get '/sign_out', to: 'users#sign_out', as: :sign_out

  scope :github do
    get "/authorize", to: "users#gh_authorize", as: :gh_authorize
    get "/authenticate", to: "users#gh_authenticate", as: :gh_authenticate
    get "/refresh", to: "users#gh_refresh", as: :gh_refresh
  end

  resources :groups, param: :path, except: :create do
    get "refresh_all", action: :gh_refresh_all, as: :refresh
    resources :groups,      only: [:create]
    resources :events,      only: [:create]
    resources :assignments, only: [:create]
    resources :memberships, only: [:create, :update, :destroy], path: "users", param: :user do
      post :toggle_active, on: :member
    end
  end

  resources :users, param: :user do
    resources :observations, only: [:create]
    put 'refresh_memberships', on: :member
    get "orphans", to: "users#orphans", on: :collection
    get "is-registered", action: :is_registered?, on: :collection
  end

  resources :assignments, only: [:show, :update, :destroy] do
    get "issues", to: "assignments#issues", as: :issues
    resources :submissions, only: [:create]
  end

  resources :events,        only: [:show, :update, :destroy] do
    resources :attendances, only: [:create]
  end

  resources :submissions,   only: [:update, :destroy]
  resources :attendances,   only: [:update, :destroy]
  resources :observations,  only: [:destroy]

end
