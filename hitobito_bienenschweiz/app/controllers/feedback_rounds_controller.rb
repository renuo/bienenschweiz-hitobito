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

  # skip authorization for create to assign_attributes before authorization
  skip_authorize_resource only: [:create]

  def create
    assign_attributes
    entry.author = current_user
    authorize!(:create, entry)
    if FeedbackRound.transaction { save_entry }
      FeedbackInvitationMailer.invite_all(entry).each(&:deliver_later)
      redirect_to(group_event_feedback_rounds_path(@group, @event))
    else
      respond_with(entry)
    end
  end

  def destroy
    super(location: group_event_feedback_rounds_path(@group, @event))
  end

  private

  def build_entry
    @event.feedback_rounds.build
  end
end
