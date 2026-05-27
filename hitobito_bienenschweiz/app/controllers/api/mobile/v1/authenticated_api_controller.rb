module Api
  module Mobile
    module V1
      class AuthenticatedApiController < ActionController::Base
        respond_to :json
        skip_before_action :verify_authenticity_token

        before_action :authenticate_kas_user!
        rescue_from ActiveRecord::RecordNotFound, with: :not_found

        protected

        attr_reader :current_person

        rescue_from ActionController::ParameterMissing do |exception|
          head :bad_request
        end

        def authenticate_kas_user!
          authentication_token = request.headers['Access-Token'] || params[:access_token]
          if authentication_token.blank?
            render json: {}, status: :unauthorized
            return
          end
          @current_person = Person.find_by(authentication_token: authentication_token)
          render json: {}, status: :unauthorized if !@current_person || !@current_person.qcontrol_inspector?
        end

        def not_found
          render json: {}, status: :not_found
        end
      end
    end
  end
end
