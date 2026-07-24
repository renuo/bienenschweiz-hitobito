# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

# Aggregate feedback report across courses matched by group(s)/event
# kind/time range, restricted to org-wide administrators. Always considers
# final feedback rounds only, regardless of the course filter (see
# FeedbackRoundAbility#if_admin for the access restriction).
class FeedbackReportsController < ApplicationController
  before_action :authorize_action

  def index
    set_default_filters
    @filter = Events::Filter::CourseList.new(current_person, params.merge(list_all_courses: true))
    @report = Feedback::Report.new(
      FeedbackRound.where(event_id: @filter.entries.ids, kind: "final")
    )
  end

  private

  def authorize_action
    authorize!(:index_report, FeedbackRound)
  end

  # No default group restriction: an admin aggregate report should default to
  # every course-offering group, unlike the per-person course list. The date
  # range defaults to a two year window since final feedback rounds are only
  # created once a course is wrapping up.
  def set_default_filters
    params[:filters] ||= {}
    params[:filters][:date_range] ||= {
      since: I18n.l(2.years.ago.to_date),
      until: I18n.l(Time.zone.today)
    }
  end
end
