module Api
  module Mobile
    module V1
      class SessionsController < ApplicationController
        respond_to :json
        skip_before_action :verify_authenticity_token

        def create
          kas_authentication_service = ::Kas::AuthenticationService.new(user_params)
          kas_authentication_service.perform
          if kas_authentication_service.ok? && kas_authentication_service.kas_user.member.qcontrol_inspector?
            response.headers['Access-Token'] = kas_authentication_service.authentication_token
            member = kas_authentication_service.kas_user.member
            render json: member.as_json(methods: %i[inspectable_intern_structures]),
                   status: :ok
          else
            render json: {}, status: :unauthorized
          end
        end

        private

        def user_params
          params.expect(user: %i[email password])
        end
      end
    end
  end
end
