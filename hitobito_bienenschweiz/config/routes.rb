# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

Rails.application.routes.draw do
  extend LanguageRouteScope

  language_scope do
    # Define wagon routes here
    resources :supervision_types
    resources :signatures, only: [:index, :edit, :update]

    resources :groups, only: [] do
      resources :events, only: [] do
        scope module: "event" do
          resource :diploma, only: :show do
            post :order
          end
        end
      end
    end

    resources :groups, only: [] do
      resources :events, only: [] do
        scope module: "event" do
          resources :participations, only: [] do
            collection do
              post :create_kas_fees
              get :new_kas_instructor_fees
              post :create_kas_instructor_fees
            end
          end
        end
      end
      resources :people, only: [] do
        resources :qcontrols do
          member do
            get :checklist, as: :checklist
            get :certificate, as: :certificate
          end
        end
        resources :supervisions
        resources :memos
      end
      resources :events, only: [] do
        get :course_materials, as: :course_materials
        collection do
          get "new_from_kind/:event_kind_id", action: :new_from_kind, as: :new_from_kind
        end
        resources :participations, only: [] do
          collection do
            resource :bulk_answers, only: [:edit, :update], controller: "event/bulk_answers"
          end
        end
      end
    end

    resources :orphan_qcontrols, only: [:index, :destroy] do
      collection do
        patch :bulk_update
      end
    end

    resources :groups, only: [] do
      resources :events, only: [] do
        resources :feedback_rounds, only: [:index, :new, :create, :show, :destroy]
      end
    end

    resources :feedback_invitations, only: [:edit, :update], param: :token
  end

  namespace :api, defaults: {formats: :json} do
    namespace :mobile do
      namespace :v1 do
        resources :quality_control_questions, only: :index
        resources :blank_inspections, only: :create
        resources :beekeepers, only: :index do
          resources :inspections, only: %i[index show create]
        end
        resources :inspection_pdf, only: :show
        post "beekeepers/:id" => "beekeepers#update", :as => :beekeeper_update
        resources :sessions, only: [:create]
      end
    end
  end
end
