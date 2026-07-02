# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::EventsController
  extend ActiveSupport::Concern

  def load_kinds # rubocop:disable Metrics/CyclomaticComplexity,Metrics/AbcSize
    return unless entry.kind_class

    layer_group_type = group&.layer_group&.class&.sti_name
    @kinds = entry.kind_class.list.without_deleted
      .includes(:kind_category)
      .to_a
      .select { |kind|
      cat = kind.kind_category
      cat.nil? || cat.layer_group_type.nil? || cat.layer_group_type == layer_group_type
    }
    @kinds |= [entry.kind] if entry.kind
  end

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
    authorize_and_set_entry(Event::Kind.find(kind_id))
    apply_question_templates
    render "new"
  end

  def new_from_kind_dropdown
    return unless params[:type] == "Event::Course"

    course = Event::Course.new(groups: [@group])
    return unless can?(:create, course)

    build_new_from_kind_dropdown
  end

  prepended do
    skip_authorize_resource only: [:course_materials, :new_from_kind]
    helper_method :new_from_kind_dropdown

    def course_materials
      @event = Event.find(params[:event_id])
      authorize! :update, @event
    end
  end

  private

  def authorize_and_set_entry(event_kind)
    template_attrs = load_event_kind_template(event_kind.id)
    @question_template_attrs = {
      application: template_attrs.delete(:application_questions) || [],
      admin: template_attrs.delete(:admin_questions) || []
    }
    course = Event::Course.new(template_attrs.merge(kind_id: event_kind.id))
    course.groups << parent
    authorize! :create, course
    model_ivar_set(course)
  end

  def apply_question_templates
    entry.dates.build if entry.dates.empty?
    entry.init_questions
    @question_template_attrs[:application].each { |a| entry.application_questions.build(a) }
    @question_template_attrs[:admin].each { |a| entry.admin_questions.build(a) }
  end

  def build_new_from_kind_dropdown
    kinds = kinds_with_templates
    return if kinds.empty?

    dropdown = Dropdown::Base.new(view_context, t("events.global.link.new_from_kind"), :plus)
    kinds.each do |kind|
      dropdown.add_item(kind.to_s, new_from_kind_group_events_path(@group, event_kind_id: kind.id))
    end
    dropdown.to_s
  end

  def kinds_with_templates
    template_dir = HitobitoBienenschweiz::Wagon.root.join("config", "event_kind_templates")
    Event::Kind.without_deleted.order(:label).select { |k| template_dir.join("#{k.id}.yml").exist? }
  end

  def load_event_kind_template(kind_id)
    template_file = HitobitoBienenschweiz::Wagon.root
      .join("config", "event_kind_templates", "#{kind_id}.yml")
    return {} unless template_file.exist?

    (YAML.safe_load_file(template_file) || {}).deep_symbolize_keys
  end
end
