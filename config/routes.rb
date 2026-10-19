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
    resource :workspace, only: %i[show update], controller: :workspace
    resource :team, only: :show, controller: :team
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

  namespace :superadmin do
    root to: "workspaces#index"
    resources :workspaces, except: :destroy do
      member do
        post :enter
      end
      resources :members, only: %i[create update destroy], controller: "workspace_members"
    end
  end

  get "auth/:provider/callback", to: "omniauth_callbacks#create"
  get "auth/failure", to: "omniauth_callbacks#failure"

  patch "workspace", to: "workspaces#update", as: :switch_workspace
  patch "active_pipeline", to: "active_pipelines#update", as: :active_pipeline
  resource :sidebar_preferences, only: :update
  resource :theme_preference, only: :update
  resource :locale_preference, only: :update

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
      patch :toggle_subscription
      post :client_portal_preview
    end
    resources :relationships, only: %i[create destroy], controller: "person_relationships"
    resources :lead_submissions, only: :show, module: :people
    resources :product_interests, only: :create, module: :people do
      member do
        patch :dismiss
      end
      resource :conversion, only: %i[new create], controller: "interest_conversions"
    end
  end
  resources :mqls, only: :index
  resources :products do
    resources :editions, except: %i[show index] do
      collection do
        get :picker
      end
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
    resource :portal_invite_link, controller: :deal_portal_invite_links, only: %i[create destroy]
    resources :line_items, controller: :deal_products, only: %i[create update destroy]
    resources :offers, only: %i[new create show destroy] do
      resources :versions, controller: :offer_versions, only: %i[new create show destroy] do
        member { patch :publish }
      end
      resources :share_links, controller: :offer_share_links, only: :destroy
    end
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

  scope "ai/:record_type/:record_id", constraints: {record_type: /people|companies|deals/} do
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
    collection { post :preview }
    member do
      patch :mark_replied
      post :retry
    end
  end
  resources :reports, only: %i[index create update destroy]
  resources :email_templates do
    collection { post :preview }
  end
  resources :email_layouts, except: %i[show] do
    collection { post :preview }
  end
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
  resource :mailjet_connection, only: %i[create update destroy]
  resource :smtp_connection, only: %i[create update destroy]
  resource :beehiiv_connection, only: %i[create update destroy] do
    post :sync, on: :member
  end
  resources :beehiiv_publications, only: %i[create update destroy]
  resources :stripe_payments, only: %i[index show] do
    member do
      post :match
      post :ignore
      post :unignore
    end
  end

  resources :webhooks, except: %i[show]
  resources :automations, except: %i[show]
  resources :alert_rules, except: %i[show]
  resources :slack_integrations, except: %i[show]
  resources :lead_forms
  resources :lead_form_templates, except: %i[show] do
    member do
      match :preview, via: %i[get post]
    end
  end
  resources :booking_pages, except: %i[show] do
    collection do
      get :calendars
    end
  end
  resources :bookings, only: %i[index] do
    member do
      patch :cancel
    end
  end
  resource :calendar_connection, only: %i[show destroy]

  get "f/:slug", to: "public/lead_forms#show", as: :public_lead_form
  post "f/:slug", to: "public/lead_forms#create"
  get "f/:slug/success", to: "public/lead_forms#success", as: :public_lead_form_success
  get "f/:slug/privacy", to: "public/lead_forms#privacy", as: :public_lead_form_privacy

  get "b/:slug", to: "public/bookings#show", as: :public_booking_page
  scope "b/:slug", as: :public_booking do
    get "recibido", to: "public/bookings#received", as: :received
    get "cancelar/:token", to: "public/booking_managements#cancel", as: :cancel
    post "cancelar/:token", to: "public/booking_managements#destroy"
    get "reprogramar/:token", to: "public/booking_managements#reschedule", as: :reschedule
    get "api/event-types", to: "public/booking_api#event_types"
    get "api/availability", to: "public/booking_api#availability"
    post "api/book", to: "public/booking_api#book"
    post "api/reschedule", to: "public/booking_api#reschedule"
  end
  get "b/:slug/:event_type", to: "public/bookings#show", as: :public_booking_event_type,
    constraints: {event_type: /[a-z0-9-]+/}

  get "offer_packages/:token/*path", to: "public/offer_packages#show", as: :offer_package_file, format: false

  get "s/:token", to: "public/offer_shares#show", as: :public_offer_share
  post "s/:token", to: "public/offer_shares#create"
  get "s/:token/ver/:grant_token", to: "public/offer_shares#confirm", as: :public_offer_share_access
  post "s/:token/ver/:grant_token", to: "public/offer_shares#access"

  scope "portal/:workspace_slug", module: "public", as: :client_portal do
    get "/", to: "client_portal_sessions#new", as: :root
    post "acceso", to: "client_portal_sessions#create", as: :access_request
    get "acceso/:token", to: "client_portal_sessions#show", as: :access_consume
    post "acceso/:token", to: "client_portal_sessions#consume"
    delete "sesion", to: "client_portal_sessions#destroy", as: :session
    get "privacidad", to: "client_portal_privacy#show", as: :privacy
    get "invitar/:token", to: "deal_portal_invites#show", as: :deal_portal_invite
    post "invitar/:token", to: "deal_portal_invites#create"
    get "invitar/:token/ver/:grant_token", to: "deal_portal_invites#confirm", as: :deal_portal_invite_access
    post "invitar/:token/ver/:grant_token", to: "deal_portal_invites#access"
    resources :offers, path: "propuestas", controller: "client_portal_offers", only: %i[index show] do
      member do
        get :share
        post :share, action: :create_share
        delete "accesos/:grant_id", action: :revoke_access, as: :revoke_access
      end
    end
  end

  get "p/:workspace_slug/:slug", to: "public/landing_pages#show", as: :public_landing_page
  get "e/preferences/:token", to: "public/email_preferences#show", as: :public_email_preferences
  patch "e/preferences/:token", to: "public/email_preferences#update"
  match "e/unsubscribe/:token", to: "public/email_preferences#unsubscribe", via: %i[get post], as: :public_email_unsubscribe
  post "e/events", to: "public/email_events#create", as: :public_email_events
  post "e/beehiiv/:token", to: "public/beehiiv_webhooks#create", as: :public_beehiiv_webhook
  post "t", to: "public/tracking#create", as: :public_tracking
  get "cream.js", to: "public/tracking#script", as: :cream_tracking_script

  resources :subscription_types, except: :show
  resources :campaigns do
    member do
      post :send_campaign
      post :send_test
      post :cancel_send
      post :mark_winner
      post :send_winner_rest
      get :recipient_count
    end
  end
  resources :segments do
    member do
      get :preview
    end
  end
  resources :journeys do
    member do
      post :enroll
      patch :toggle_active
    end
    resources :enrollments, only: :update, controller: "journey_enrollments"
  end
  resources :scoring_rules, except: :show do
    collection do
      post :recalculate
    end
  end
  resource :marketing_attribution, only: :show, controller: "marketing_attribution"

  namespace :api do
    get "docs", to: "docs#show"
    get "openapi.yaml", to: "docs#openapi", as: :openapi
    namespace :v1 do
      resources :people do
        member do
          get :marketing
          patch :subscription
        end
        resources :product_interests, only: %i[index create], module: :marketing
        resources :attachments, only: :create, controller: "person_attachments"
        resources :emails, only: :create, controller: "person_emails"
      end
      namespace :marketing do
        resources :mqls, only: %i[index create]
        resources :subscription_types, only: :index
        resources :subscriptions, only: :index
        resources :campaigns, only: %i[index show] do
          resources :sends, only: :create, controller: "campaign_sends" do
            member { post :cancel }
          end
        end
        resources :segments, only: %i[index show]
        resources :journeys, only: %i[index show] do
          member { post :enroll }
        end
        resources :scoring_rules, only: :index
        resource :attribution, only: :show, controller: "attribution"
        resources :email_templates, only: :index
        resources :lead_forms, only: :index
        resources :mql_conversions, only: :create
      end
      resources :companies
      resources :pipelines, only: %i[index show]
      resources :products, only: %i[index show]
      resources :deals do
        resources :notes, only: :create, controller: "deal_notes"
        resources :emails, only: :create, controller: "deal_emails"
        resources :offers, only: :create, controller: "deal_offers"
      end
      resources :tasks do
        member do
          post :complete_and_replace
        end
      end
      get "gmail/context", to: "gmail_contexts#show"
      post "gmail/threads/status", to: "gmail_threads#status"
      post "gmail/threads/link", to: "gmail_threads#link"
      post "gmail/deals/:deal_id/contacts", to: "gmail_deal_contacts#create"
    end
  end

  get "terms", to: "legal_pages#terms"
  get "privacy", to: "legal_pages#privacy"
  get "support", to: "legal_pages#support"

  get "up" => "rails/health#show", :as => :rails_health_check
end
