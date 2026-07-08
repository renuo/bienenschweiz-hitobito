# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::EventsController
  extend ActiveSupport::Concern

  def load_sister_groups
    if group.is_a?(Group::Sektion)
      @groups = Group::Sektion.all.reorder(:code)
    else
      master = @event.groups.first
      @groups = master.self_and_sister_groups.reorder(:name)
    end
    # union to include assigned deleted events
    @groups = (@groups | @event.groups)
  end

  def new_from_kind
    kind_id = request.path_parameters.delete(:event_kind_id)
    self.action_name = "new"
    event_kind = Event::Kind.find(kind_id)
    template_attrs = load_event_kind_template(event_kind.id)
    application_question_attrs = template_attrs.delete(:application_questions) || []
    admin_question_attrs = template_attrs.delete(:admin_questions) || []
    course = Event::Course.new(template_attrs.merge(kind_id: event_kind.id))
    course.groups << parent
    authorize! :create, course
    model_ivar_set(course)
    entry.dates.build if entry.dates.empty?
    entry.init_questions
    application_question_attrs.each { |attrs| entry.application_questions.build(attrs) }
    admin_question_attrs.each { |attrs| entry.admin_questions.build(attrs) }
    render "new"
  end

  prepended do
    skip_authorize_resource only: [:course_materials, :new_from_kind]

    def course_materials
      @event = Event.find(params[:event_id])
      authorize! :update, @event
    end
  end

  private

  def load_event_kind_template(kind_id)
    template_file = HitobitoBienenschweiz::Wagon.root
      .join("config", "event_kind_templates", "#{kind_id}.yml")
    return {} unless template_file.exist?

    (YAML.safe_load_file(template_file) || {}).deep_symbolize_keys
  end
end
