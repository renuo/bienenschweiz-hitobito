# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::EventsController
  extend ActiveSupport::Concern

  # Templates for courses are keyed by Event::Kind id, templates for plain
  # events by their file name (slug), as plain events have no kind.
  KIND_TEMPLATE_DIR = "event_kind_templates"
  EVENT_TEMPLATE_DIR = "event_templates"

  def load_kinds # rubocop:disable Metrics/CyclomaticComplexity,Metrics/AbcSize
    return unless entry.kind_class

    layer_group_type = group.layer_group.class.sti_name
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
    kind = Event::Kind.find(kind_id)
    render_new_from_template(Event::Course, load_template(KIND_TEMPLATE_DIR, kind.id),
      kind_id: kind.id)
  end

  def new_from_template
    slug = request.path_parameters.delete(:event_template)
    attrs = event_templates[slug]
    raise ActiveRecord::RecordNotFound, "No event template '#{slug}'" if attrs.nil?

    render_new_from_template(Event, attrs.except(:label))
  end

  def new_from_kind_dropdown
    if params[:type] == Event::Course.sti_name
      build_new_from_kind_dropdown
    else
      build_new_from_template_dropdown
    end
  end

  prepended do
    skip_authorize_resource only: [:course_materials, :new_from_kind, :new_from_template]
    helper_method :new_from_kind_dropdown

    # Course materials only exist on courses. Authorize first so that people
    # without access to the event get the usual AccessDenied rather than a
    # redirect to a page they may not be allowed to see.
    def course_materials
      @event = Event.find(params[:event_id])
      authorize! :update, @event
      return if @event.is_a?(Event::Course)

      redirect_to group_event_path(@group, @event),
        alert: t("events.course_materials.not_a_course")
    end
  end

  private

  # Builds the given event type from the template attributes, authorizes it and
  # renders the regular new form with everything prefilled.
  def render_new_from_template(event_class, template_attrs, extra_attrs = {})
    self.action_name = "new"
    question_attrs = extract_question_attrs(template_attrs)
    event = event_class.new(template_attrs.merge(extra_attrs))
    event.groups << parent
    authorize! :create, event
    model_ivar_set(event)
    apply_question_templates(question_attrs)
    render "new"
  end

  def extract_question_attrs(template_attrs)
    {
      application: template_attrs.delete(:application_questions) || [],
      admin: template_attrs.delete(:admin_questions) || []
    }
  end

  def apply_question_templates(question_attrs)
    entry.dates.build
    entry.init_questions
    question_attrs[:application].each { |a| entry.application_questions.build(a) }
    question_attrs[:admin].each { |a| entry.admin_questions.build(a) }
  end

  def build_new_from_kind_dropdown
    course = Event::Course.new(groups: [@group])
    # :nocov:
    return unless can?(:create, course)
    # :nocov:

    kinds = kinds_with_templates
    return if kinds.empty?

    dropdown = Dropdown::Base.new(view_context, t("events.global.link.new_from_kind"), :plus)
    kinds.each do |kind|
      dropdown.add_item(kind.to_s, new_from_kind_group_events_path(@group, event_kind_id: kind.id))
    end
    dropdown.to_s
  end

  def build_new_from_template_dropdown
    event = Event.new(groups: [@group])
    # :nocov:
    return unless can?(:create, event)
    # :nocov:

    templates = event_templates
    return if templates.empty?

    dropdown = Dropdown::Base.new(view_context, t("events.global.link.new_from_template"), :plus)
    templates.each do |slug, attrs|
      dropdown.add_item(template_label(slug, attrs),
        new_from_template_group_events_path(@group, event_template: slug))
    end
    dropdown.to_s
  end

  def kinds_with_templates
    dir = template_dir(KIND_TEMPLATE_DIR)
    Event::Kind.without_deleted.order(:label).select { |k| dir.join("#{k.id}.yml").exist? }
  end

  # All plain event templates, keyed by slug and ordered by their label.
  # Files starting with an underscore (e.g. _example.yml) are documentation only.
  def event_templates
    slugs = Dir.glob(template_dir(EVENT_TEMPLATE_DIR).join("*.yml"))
      .map { |path| File.basename(path, ".yml") }
      .reject { |slug| slug.start_with?("_") }
    templates = slugs.index_with { |slug| load_template(EVENT_TEMPLATE_DIR, slug) }
    templates.sort_by { |slug, attrs| template_label(slug, attrs) }.to_h
  end

  def template_label(slug, attrs)
    attrs[:label].presence || slug.humanize
  end

  def template_dir(name)
    HitobitoBienenschweiz::Wagon.root.join("config", name)
  end

  def load_template(dir, key)
    template_file = template_dir(dir).join("#{key}.yml")
    return {} unless template_file.exist?

    (YAML.safe_load_file(template_file) || {}).deep_symbolize_keys
  end
end
