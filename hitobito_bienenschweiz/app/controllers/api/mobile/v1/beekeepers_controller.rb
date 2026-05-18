module Api
  module Mobile
    module V1
      class BeekeepersController < AuthenticatedApiController
        before_action :set_beekeeper, only: :update

        def index
          @beekeepers = insert_empty_name_placeholders(inspectable_beekeepers.order(:lastname, :firstname))
          render json: @beekeepers.as_json(only: %i[id firstname lastname affix_1 affix_2 affix_3 street
                                                    house_no zip location kanton birthdate honey_yield hive_count],
                                           methods: %i[telephone mobile email])
        end

        def update
          head :no_content, status: :ok if MemberChangeRequestService.new(@beekeeper, current_person.member,
                                                                          beekeeper_params.to_h).request_change
        end

        private

        def inspectable_beekeepers
          current_person.member.inspectable_beekeepers
        end

        def set_beekeeper
          @beekeeper = inspectable_beekeepers.find(params[:id])
        end

        def beekeeper_params
          params.expect(member: %i[firstname lastname street house_no zip location
                                   email telephone mobile remark hive_count honey_yield])
        end

        def insert_empty_name_placeholders(beekeepers)
          beekeepers.map do |beekeeper|
            beekeeper['firstname'] ||= ''
            beekeeper['lastname'] ||= ''

            if beekeeper['firstname'].blank? && beekeeper['lastname'].blank?
              beekeeper['lastname'] = I18n.t('members.empty_name_placeholder',
                                             selectline_customer_number: beekeeper.selectline_customer_number,
                                             locale: :de)
            end

            beekeeper
          end
        end
      end
    end
  end
end
