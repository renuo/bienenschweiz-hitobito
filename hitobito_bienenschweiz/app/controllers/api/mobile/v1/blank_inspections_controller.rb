# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Api
  module Mobile
    module V1
      class BlankInspectionsController < AuthenticatedApiController
        def create # rubocop:disable Metrics/AbcSize
          Rails.logger.info("Creating blank Qcontrol")
          Rails.logger.info("Member params: #{params[:member]}")
          Rails.logger.info("Qcontrol params: #{params[:inspection]}")
          @qcontrol = Qcontrol.new(inspection_params)
          @qcontrol.author_name = "VDRB-APP"
          @qcontrol.from_app = true
          @qcontrol.inspector_id = current_person.id

          if new_member_params && @qcontrol.save
            InspectionMailer.blank_inspection_info_mailer(params[:member], @qcontrol.id).deliver_now
            head :no_content
          else
            render status: :unprocessable_content, json: {errors: @qcontrol.errors}
          end
        end

        private

        def inspection_params
          ret = params.expect(inspection: [
            :intern_structure_id, :title, :control_date, :no_control_reason,
            :other_reason_for_no_control, :business_handover_to, :with_voucher,
            {quality_control_answers_attributes: [%i[quality_control_question_id
              deadline_at notes fulfilled]]}
          ])
          inspectable_groups = current_person.groups
            .where(roles: {type: [
              Group::Produkte::FachpersonProdukte.sti_name,
              Group::Produkte::FachpersonProdukteInAusbildung.sti_name
            ]})
            .order(roles: {start_on: "asc"})
          ret[:group_id] = ret.delete(:intern_structure_id) || inspectable_groups.first.parent.id
          ret[:no_control_reason] ||= :no_reason
          ret
        end

        def new_member_params
          params.expect(member: %i[firstname lastname street house_no zip location email telephone
            mobile])
        end
      end
    end
  end
end
