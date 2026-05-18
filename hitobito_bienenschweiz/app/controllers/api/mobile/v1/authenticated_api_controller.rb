module Api
  module Mobile
    module V1
      class AuthenticatedApiController < ActionController::Base
        respond_to :json
        skip_before_action :verify_authenticity_token

        before_action :authenticate_kas_user!

        protected

        attr_reader :current_person

        rescue_from ActionController::ParameterMissing do |exception|
          head :bad_request
        end

        def authenticate_kas_user!
          # TODO: implement
          authentication_token = request.headers['Access-Token'] || params[:access_token]
          @current_person = Person.find_by(authentication_token: authentication_token)
          render json: {}, status: :unauthorized if !@current_person || !@current_person.qcontrol_inspector?
        end
      end
    end
  end
end
