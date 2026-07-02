# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Event::DiplomasController < ApplicationController
  before_action :load_group_and_event

  def show
    authorize! :print, @event
    pdf = Export::Pdf::Event::Diploma.new(@event).render
    send_data pdf,
      type: :pdf,
      disposition: "attachment",
      filename: Export::Pdf::Event::Diploma.filename(@event)
  end

  def order
    authorize! :edit, @event
    @event.update_column(:diplomas_ordered_at, Time.current)
    DiplomaMailer.order(@event).deliver_later
    redirect_to group_event_qualifications_path(@group, @event),
      notice: t("event.diploma.order_success")
  end

  private

  def load_group_and_event
    @group = Group.find(params[:group_id])
    @event = @group.events.find(params[:event_id])
  end
end
