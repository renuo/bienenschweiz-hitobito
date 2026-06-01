# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


module Api
  module Mobile
    module V1
      class QualityControlQuestionsController < AuthenticatedApiController
        def index
          @sections = QualityControlSection.for_current_version
          render json: @sections.as_json(only: %i[id title number],
            include: {quality_control_questions:
                           {only: %i[id title number description
                             inspection_notes]}})
        end
      end
    end
  end
end
