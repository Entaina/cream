Rails.application.routes.draw do
  mount Mailbin::Engine, at: "/mailbin" if Rails.env.development?
  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
  end
  # RFC 7591 dynamic client registration + RFC 8414/9728 metadata (MCP spec).
  post "oauth/register", to: "oauth_registrations#create"
  get ".well-known/oauth-authorization-server", to: "well_known#oauth_authorization_server"
  get ".well-known/oauth-protected-resource", to: "well_known#oauth_protected_resource"
  get ".well-known/oauth-protected-resource/mcp", to: "well_known#oauth_protected_resource"

  # MCP server (Streamable HTTP transport)
  post "mcp", to: "mcp#handle"
  get "mcp", to: "mcp#method_not_allowed"
  delete "mcp", to: "mcp#method_not_allowed"

  resources :api_tokens, only: %i[index create destroy]

  namespace :settings do
    resource :team, only: %i[show update], controller: :team
    resource :profile, only: %i[show update], controller: :profile
    resources :custom_fields, except: %i[show]
  end

  resources :invitations, only: %i[create destroy] do
    member do
      post :resend
    end
  end
  resources :memberships, only: %i[update destroy]

  get "invitations/accept/:token", to: "invitation_accepts#show", as: :accept_invitation
  post "invitations/accept/:token", to: "invitation_accepts#create"

  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  get "auth/:provider/callback", to: "omniauth_callbacks#create"
  get "auth/failure", to: "omniauth_callbacks#failure"

  patch "workspace", to: "workspaces#update", as: :switch_workspace
  patch "active_pipeline", to: "active_pipelines#update", as: :active_pipeline
  resource :sidebar_preferences, only: :update
  resource :theme_preference, only: :update

  root "dashboard#show"
  resource :sales_briefing, only: :create

  resources :companies do
    collection do
      get :picker
      get :duplicates
    end
    member do
      match :merge, via: %i[get post]
    end
  end
  resources :people do
    collection do
      get :duplicates
    end
    member do
      match :merge, via: %i[get post]
    end
    resources :relationships, only: %i[create destroy], controller: "person_relationships"
  end
  resources :products
  resources :editions, except: %i[show] do
    collection do
      get :picker
    end
  end
  resources :pipelines, except: %i[show] do
    collection do
      post :from_template
    end
    member do
      post :duplicate
      patch :reorder_stages
    end
  end
  resources :pipeline_stages, only: [] do
    resources :stage_triggers, shallow: true
    resources :stage_field_formats, except: %i[show], shallow: true
    resources :stage_conditions, except: %i[show], shallow: true
  end
  resources :deals do
    member do
      patch :move
      patch :move_pipeline
      post :duplicate
    end
    collection do
      get :board
      get :picker
    end
    resources :deal_accesses, only: %i[create destroy]
    resources :line_items, controller: :deal_products, only: %i[create update destroy]
    resources :versions, controller: :deal_versions, only: %i[index show]
  end
  resources :notes, only: %i[create update destroy]
  resources :tasks, only: %i[index create update destroy] do
    member do
      patch :toggle
    end
  end
  resources :lists do
    resources :entries, controller: :list_entries, only: %i[create destroy]
  end
  resources :saved_views, only: %i[create update destroy]
  get "search", to: "search#index"
  get "ai_search", to: "ai_search#index"
  post "okm_chat", to: "okm_chats#create", as: :okm_chat
  post "okm_chat/actions", to: "okm_chats#execute_action", as: :okm_chat_actions

  scope "ai/:record_type/:record_id", constraints: { record_type: /people|companies|deals/ } do
    post "summary", to: "record_ai#summary", as: :record_ai_summary
    post "draft_email", to: "record_ai#draft_email", as: :record_ai_draft_email
    post "next_steps", to: "record_ai#next_steps", as: :record_ai_next_steps
    post "create_task", to: "record_ai#create_task", as: :record_ai_create_task
    post "enrich", to: "record_ai#enrich", as: :record_ai_enrich
  end

  resources :comments, only: %i[create destroy]
  resources :record_attachments, only: %i[create destroy]
  resources :notifications, only: %i[index update] do
    collection do
      patch :mark_all_read
    end
  end
  resource :import, only: %i[new create], controller: :imports
  get "exports/:record_type", to: "exports#show", as: :export

  resources :record_emails, only: %i[create destroy] do
    member { patch :mark_replied }
  end
  resources :reports, only: %i[index create update destroy]
  resources :email_templates, except: %i[show]
  resource :mail_merge, only: %i[new create], controller: :mail_merges do
    get :recipients_count
  end
  get "email_tracking/open/:token", to: "email_tracking#open", as: :email_tracking_open
  get "email_tracking/click/:token", to: "email_tracking#click", as: :email_tracking_click
  resource :gmail_connection, only: %i[show update destroy] do
    post :sync, on: :member
  end
  resource :stripe_connection, only: %i[show create update destroy] do
    post :sync, on: :member
  end
  resources :stripe_payments, only: %i[index show] do
    member do
      post :match
      post :ignore
      post :unignore
    end
  end

  resources :webhooks, except: %i[show]
  resources :automations, except: %i[show]
  resources :alert_rules, except: %i[show] do
    resources :alert_conditions, except: %i[show], shallow: true
  end
  resources :slack_integrations, except: %i[show]
  resources :lead_forms, except: %i[show]
  resources :booking_pages, except: %i[show] do
    collection do
      get :calendars
    end
  end
  resource :calendar_connection, only: %i[show destroy]

  get "f/:slug", to: "public/lead_forms#show", as: :public_lead_form
  post "f/:slug", to: "public/lead_forms#create"
  get "f/:slug/success", to: "public/lead_forms#success", as: :public_lead_form_success

  get "b/:slug", to: "public/bookings#show", as: :public_booking_page
  scope "b/:slug", as: :public_booking do
    get "api/event-types", to: "public/booking_api#event_types"
    get "api/availability", to: "public/booking_api#availability"
    post "api/book", to: "public/booking_api#book"
  end

  namespace :api do
    namespace :v1 do
      resources :people
      resources :companies
      resources :deals
      get "gmail/context", to: "gmail_contexts#show"
      post "gmail/threads/status", to: "gmail_threads#status"
      post "gmail/threads/link", to: "gmail_threads#link"
    end
  end

  get "terms", to: "legal_pages#terms"
  get "privacy", to: "legal_pages#privacy"
  get "support", to: "legal_pages#support"

  get "up" => "rails/health#show", :as => :rails_health_check
end
