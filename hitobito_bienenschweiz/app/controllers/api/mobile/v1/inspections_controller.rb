# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Api
  module Mobile
    module V1
      class InspectionsController < AuthenticatedApiController
        before_action :set_beekeeper
        before_action :check_no_control_reason, only: :create

        def index
          @inspections = Qcontrol.where(person_id: @beekeeper.id).order(control_date: :desc)
          render json: @inspections.map(&:as_mobile_json)
        end

        def show
          @inspection = @beekeeper.qcontrols.find_by(id: params[:id])
          if @inspection
            render json: @inspection.as_full_mobile_json
          else
            head :not_found
          end
        end

        def create
          Rails.logger.info("Creating Qcontrol: #{params[:inspection]}")
          @qcontrol = @beekeeper.qcontrols.build(inspection_params)
          @qcontrol.author_name = "VDRB-APP"
          @qcontrol.from_app = true
          @qcontrol.inspector_id = current_person.id
          @qcontrol.person = @beekeeper

          if @qcontrol.save
            head :no_content
          else
            render status: :unprocessable_content, json: {errors: @qcontrol.errors}
          end
        end

        private

        def set_beekeeper
          @beekeeper = current_person.inspectable_beekeepers.find_by(id: params[:beekeeper_id])
          head :not_found if @beekeeper.blank?
        end

        def inspection_params
          # TODO: When changing something here, change it also in `blank_inspections_controller`
          ret = params.expect(inspection: [:group_id, :title, :control_date, :no_control_reason,
            :other_reason_for_no_control, :business_handover_to, :with_voucher,
            {quality_control_answers_attributes: [%i[quality_control_question_id
              deadline_at notes fulfilled]]}])

          valid_memberships = @beekeeper.roles.where(
            type: Bienenschweiz::Person::BEEKEEPER_ROLES
          ).order(:start_on)
          ret[:group_id] = valid_memberships.first.group_id
          ret[:no_control_reason] ||= :no_reason
          ret
        end

        def check_no_control_reason
          # inspired_by: https://github.com/rails/rails/issues/13971
          return unless inspection_params.key?("no_control_reason")
          return if Qcontrol.no_control_reasons.key?(inspection_params[:no_control_reason])

          render status: :unprocessable_content, json: {
            errors:
              "no_control_reason: #{inspection_params[:no_control_reason]} not in enum value list"
          }
        end
      end
    end
  end
end
