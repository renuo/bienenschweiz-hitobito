# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Api
  module Mobile
    module V1
      class InspectionPdfController < AuthenticatedApiController
        before_action :set_qcontrol

        def show
          return head :not_found if @qcontrol.nil?

          pdf = Export::Pdf::Qcontrol::Checklist.new(@qcontrol).render

          send_data pdf, type: "application/pdf",
            disposition: "inline",
            filename: "Betriebspruefung.pdf"
        end

        private

        def set_qcontrol
          @qcontrol = Qcontrol.where(person: current_person.inspectable_beekeepers)
            .find_by(id: params[:id])
        end
      end
    end
  end
end
