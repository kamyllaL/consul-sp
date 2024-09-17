namespace :edition do
  root to: "dashboard#index"

  namespace :legislation do
    resources :processes, except: [:new, :create, :destroy] do
      resources :questions
      resources :proposals do
        member { patch :toggle_selection }
      end
      resources :draft_versions
      resources :milestones
      resources :progress_bars, except: :show
      resource :homepage, only: [:edit, :update]
      resources :topics, except: [:show] do
        get :document, on: :collection
      end
      resources :topic_levels, except: [:index, :show]
    end
  end

  resources :milestone_statuses, only: [:index, :new, :create, :update, :edit, :destroy]
end