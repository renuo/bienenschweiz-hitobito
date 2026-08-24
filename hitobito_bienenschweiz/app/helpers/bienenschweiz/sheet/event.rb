# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz
module Bienenschweiz::Sheet::Event
  extend ActiveSupport::Concern

  prepended do
    tabs << Sheet::Tab.new(
      "events.form_tabs.course_materials",
      :group_event_course_materials_path,
      if: (lambda do |view, _group, event|
        view.can?(:update, event)
      end)
    )

    tabs << Sheet::Tab.new(
      "events.form_tabs.feedback_rounds",
      :group_event_feedback_rounds_path,
      if: (lambda do |view, _group, event|
        event.course? && view.can?(:read, FeedbackRound.new(event: event))
      end)
    )
  end
end
