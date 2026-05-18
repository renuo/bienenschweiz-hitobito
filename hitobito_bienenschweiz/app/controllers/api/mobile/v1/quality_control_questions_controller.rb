module Api
  module Mobile
    module V1
      class QualityControlQuestionsController < AuthenticatedApiController
        def index
          @sections = QualityControlSection.for_current_version
          render json: @sections.as_json(only: %i[id title number],
                                         include: { quality_control_questions:
                                                        { only: %i[id title number description inspection_notes] } })
        end
      end
    end
  end
end
