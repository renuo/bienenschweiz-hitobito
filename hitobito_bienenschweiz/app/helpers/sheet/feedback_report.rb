# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

# No parent_sheet on purpose: FeedbackReportsController#index should resolve
# to this sheet itself (Sheet::Base#sheet_for_controller redirects :index
# actions to the parent_sheet when one is set), so its own left nav renders.
#
# Renders the exact same left nav as Sheet::Events::Course (courses' kind
# category filters, plus the report link itself), so the sub-nav under
# "Kurse" looks and behaves identically whether you're on /list_courses or
# /feedback_reports. Sheet::Events::Course renders "nav_left" as a bare
# name, which resolves relative to the current controller's own view path;
# here it must be given explicitly since FeedbackReportsController's own
# view path is "feedback_reports/".
module Sheet
  class FeedbackReport < Base
    def left_nav?
      true
    end

    def render_left_nav
      view.render("events/courses/nav_left")
    end
  end
end
