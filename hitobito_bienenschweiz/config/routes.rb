# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.


Rails.application.routes.draw do
  extend LanguageRouteScope

  language_scope do
    # Define wagon routes here
    resources :groups, only: [] do
      resources :people, only: [] do
        resources :qcontrols
      end
    end
  end

  namespace :api, defaults: { formats: :json } do
    namespace :mobile do
      namespace :v1 do
        resources :quality_control_questions, only: :index
        resources :blank_inspections, only: :create
        resources :beekeepers, only: :index do
          resources :inspections, only: %i[index show create]
        end
        resources :inspection_pdf, only: :show
        post 'beekeepers/:id' => 'beekeepers#update', as: :beekeeper_update
        resources :sessions, only: [:create]
      end
    end
  end
end
