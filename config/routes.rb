Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  get "up" => "rails/health#show", as: :rails_health_check
  resource :session, only: [ :new, :create, :destroy ]
  resources :import_batches, only: [ :index, :new, :create, :show ] do
    post :context, on: :collection
    member do
      patch :headers, action: :update_headers
      patch :confirm_mapping
      post :resume
      get :download
    end
  end
  resources :athletes, :race_results, only: :index
  root "import_batches#index"
end
