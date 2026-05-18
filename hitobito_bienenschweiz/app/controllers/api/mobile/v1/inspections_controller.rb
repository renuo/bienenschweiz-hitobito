module Api
  module Mobile
    module V1
      class InspectionsController < AuthenticatedApiController
        before_action :set_beekeeper
        before_action :check_no_control_reason, only: :create

        def index
          @inspections = Qcontrol.where(member_id: @beekeeper.id).order(control_date: :desc)
          render json: @inspections.as_json(only: %i[id member_id author_id title control_date])
        end

        def show
          @inspection = @beekeeper.qcontrols.find_by(id: params[:id])
          if @inspection
            render json: @inspection.as_json(
              only: %i[id title document control_date no_control_reason
                       other_reason_for_no_control business_handover_to with_voucher],
              include: { member: { only: %i[id firstname lastname] },
                         author: { only: %i[id firstname lastname] },
                         intern_structure: { only: %i[id code name] },
                         quality_control_answers: { except: %i[updated_at created_at] } }
            )
          else
            head :not_found
          end
        end

        def create
          Rails.logger.info("Creating Qcontrol: #{params[:inspection]}")
          @qcontrol = @beekeeper.qcontrols.build(inspection_params)
          @qcontrol.author_name = 'VDRB-APP'
          @qcontrol.from_app = true
          @qcontrol.inspector_id = current_person.id
          @qcontrol.member = @beekeeper

          if @qcontrol.save
            head :no_content
          else
            render status: :unprocessable_content, json: { errors: @qcontrol.errors }
          end
        end

        private

        def set_beekeeper
          @beekeeper = current_person.member.inspectable_beekeepers.find_by(id: params[:beekeeper_id])
          head :not_found if @beekeeper.blank?
        end

        def inspection_params
          # TODO: When changing something here, change it also in `blank_inspections_controller`
          ret = params.expect(inspection: [:group_id, :title, :control_date, :no_control_reason,
                                           :other_reason_for_no_control, :business_handover_to, :with_voucher,
                                           { quality_control_answers_attributes: [%i[quality_control_question_id
                                                                                     deadline_at notes fulfilled]] }])

          valid_memberships = @beekeeper.memberships.active.where(role: Role.qcontrol_beekeeper).order(:valid_from)
          ret[:group_id] = valid_memberships.first.group_id
          ret[:no_control_reason] ||= :no_reason
          ret
        end

        def check_no_control_reason
          # inspired_by: https://github.com/rails/rails/issues/13971
          return unless inspection_params.key?('no_control_reason')
          return if Qcontrol.no_control_reasons.key?(inspection_params[:no_control_reason])

          render status: :unprocessable_content, json: {
            errors: "no_control_reason: #{inspection_params[:no_control_reason]} not in enum value list"
          }
        end
      end
    end
  end
end
