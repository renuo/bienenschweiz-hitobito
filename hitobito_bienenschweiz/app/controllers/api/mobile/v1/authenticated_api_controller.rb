# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Api
  module Mobile
    module V1
      class AuthenticatedApiController < ActionController::API
        respond_to :json

        before_action :authenticate_inspector!
        rescue_from ActiveRecord::RecordNotFound do
          render json: {}, status: :not_found
        end
        rescue_from ActionController::ParameterMissing do
          head :bad_request
        end

        protected

        attr_reader :current_person

        def authenticate_inspector!
          authentication_token = request.headers["Access-Token"] || params[:access_token]
          if authentication_token.blank?
            render json: {}, status: :unauthorized
            return
          end
          @current_person = Person.find_signed(authentication_token, purpose: :beeaudit)
          if !@current_person || !@current_person.qcontrol_inspector?
            render json: {},
              status: :unauthorized
          end
        end
      end
    end
  end
end
