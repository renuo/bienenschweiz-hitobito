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

        before_action :authenticate_kas_user!
        rescue_from ActiveRecord::RecordNotFound, with: :not_found

        protected

        attr_reader :current_person

        rescue_from ActionController::ParameterMissing do |exception|
          head :bad_request
        end

        def authenticate_kas_user!
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

        def not_found
          render json: {}, status: :not_found
        end
      end
    end
  end
end
