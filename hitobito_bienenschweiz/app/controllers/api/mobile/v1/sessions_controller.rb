module Api
  module Mobile
    module V1
      class SessionsController < ActionController::API
        respond_to :json

        def create
          person = Person.find_by(email: user_params[:email])
          if person&.valid_password?(user_params[:password]) && person.qcontrol_inspector?
            response.headers["Access-Token"] = person.authentication_token
            render json: person.as_json(methods: %i[inspectable_intern_structures]),
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
