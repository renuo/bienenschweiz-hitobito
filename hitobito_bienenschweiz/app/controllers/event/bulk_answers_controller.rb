# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Event::BulkAnswersController < ApplicationController
  before_action :load_group_and_event
  before_action :authorize_action
  prepend Nestable
  self.nesting = Group, Event

  decorates :event
  def edit
    @questions = @event.questions.where(admin: true).list.includes(:translations)
    @participations = load_participations
  end

  def update
    valid_ids = event_answer_ids
    params[:answers]&.each do |answer_id_str, answer_attrs|
      answer_id = answer_id_str.to_i
      next unless valid_ids.include?(answer_id)

      Event::Answer.find(answer_id).update(answer: answer_attrs[:answer])
    end
    redirect_to edit_group_event_bulk_answers_path(@group, @event), notice: t(".success")
  end

  private

  def load_group_and_event
    @group = Group.find(params[:group_id])
    @event = Event.find(params[:event_id])
  end

  def authorize_action
    authorize! :update, @event
  end

  def load_participations
    @event.participations
      .includes(answers: {question: :translations}, participant: [])
      .sort_by { |p| p.person.full_name.to_s }
  end

  def event_answer_ids
    Set.new(
      Event::Answer
        .joins(:participation)
        .where(event_participations: {event_id: @event.id})
        .ids
    )
  end
end
