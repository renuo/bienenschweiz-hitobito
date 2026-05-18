module Api
  module Mobile
    module V1
      class InspectionPdfController < AuthenticatedApiController
        before_action :set_qcontrol

        def show
          return head :not_found if @qcontrol.nil?

          send_data PdfService.render(:checklist, @qcontrol),
                    filename: 'Betriebspruefung.pdf',
                    type: 'application/pdf',
                    disposition: 'inline'
        end

        private

        def set_qcontrol
          inspectable_beekeepers = current_person.member.inspectable_beekeepers
          @qcontrol = Qcontrol.where(member_id: inspectable_beekeepers).find_by(id: params[:id])
        end
      end
    end
  end
end
