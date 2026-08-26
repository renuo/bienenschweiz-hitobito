# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class FeedbackRoundsController < CrudController
  self.nesting = Group, Event

  self.permitted_attrs = [:kind]

  decorates :group, :event

  # load parents before authorization
  prepend_before_action :parent

  # :report is not part of CrudController::ACTIONS, so load the entry here
  # too, otherwise cancancan's authorize_resource before_action would not
  # find @feedback_round yet and fall back to a permissive parent-only check.
  prepend_before_action :entry, only: [:report]

  # Feedback rounds only exist on courses. Guard before anything else runs:
  # loading the entry would explode on Event#feedback_rounds for other types.
  prepend_before_action :assert_course

  # skip authorization for create to assign_attributes before authorization
  skip_authorize_resource only: [:create]

  def create
    assign_attributes
    entry.author = current_user
    authorize!(:create, entry)
    if save_entry
      FeedbackInvitationMailer.invite_all(entry).each(&:deliver_later)
      redirect_to(group_event_feedback_rounds_path(@group, @event))
    else
      respond_with(entry)
    end
  end

  def destroy
    super(location: group_event_feedback_rounds_path(@group, @event))
  end

  def report
    @report = Feedback::Report.new(FeedbackRound.where(id: entry.id))
  end

  def export
    authorize!(:export, entry)
    send_data Export::Tabular::FeedbackRounds::Result.xlsx(entry, current_ability),
      type: :xlsx, disposition: "attachment", filename: export_filename
  end

  private

  def assert_course
    parent # loads @group and @event
    return if @event.is_a?(Event::Course)

    redirect_to group_event_path(@group, @event), alert: t("feedback_rounds.not_a_course")
  end

  def build_entry
    @event.feedback_rounds.build
  end

  def export_filename
    "#{@event.name}-feedback-#{entry.kind}".parameterize + ".xlsx"
  end
end
