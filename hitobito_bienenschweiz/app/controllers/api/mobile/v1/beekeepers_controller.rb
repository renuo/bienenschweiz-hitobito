# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


module Api
  module Mobile
    module V1
      class BeekeepersController < AuthenticatedApiController
        before_action :set_beekeeper, only: :update

        def index
          @beekeepers = insert_empty_name_placeholders(inspectable_beekeepers.order(:last_name,
            :first_name))
          render json: @beekeepers.map(&:as_mobile_json)
        end

        def update
          if MemberChangeRequestService.new(@beekeeper, current_person,
            beekeeper_params.to_h).request_change
            head :no_content,
              status: :ok
          end
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
            beekeeper["first_name"] ||= ""
            beekeeper["last_name"] ||= ""

            if beekeeper["first_name"].blank? && beekeeper["last_name"].blank?
              beekeeper["last_name"] = I18n.t("beeaudit.empty_name_placeholder",
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
