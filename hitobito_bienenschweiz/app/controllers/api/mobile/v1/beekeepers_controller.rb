module Api
  module Mobile
    module V1
      class BeekeepersController < AuthenticatedApiController
        before_action :set_beekeeper, only: :update

        def index
          @beekeepers = insert_empty_name_placeholders(inspectable_beekeepers.order(:last_name, :first_name))
          render json: @beekeepers.map(&:as_mobile_json)
        end

        def update
          head :no_content, status: :ok if MemberChangeRequestService.new(@beekeeper, current_person,
                                                                          beekeeper_params.to_h).request_change
        end

        private

        def inspectable_beekeepers
          current_person.inspectable_beekeepers
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
            beekeeper['first_name'] ||= ''
            beekeeper['last_name'] ||= ''

            if beekeeper['first_name'].blank? && beekeeper['last_name'].blank?
              beekeeper['last_name'] = I18n.t('beeaudit.empty_name_placeholder',
                                              id: beekeeper.id,
                                             locale: :de)
            end

            beekeeper
          end
        end
      end
    end
  end
end
