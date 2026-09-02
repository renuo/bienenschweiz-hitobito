# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

TEMPLATE_FIELDS = %w[
  description location cost maximum_participants minimum_participants
  requires_approval external_applications applications_cancelable
  display_booking_info participations_visible export_to_website
  delivery_address billing_address application_conditions
  required_contact_attrs hidden_contact_attrs visible_contact_attributes
  motto
].freeze

# Plain events have neither a kind nor the course specific booking fields.
EVENT_TEMPLATE_FIELDS = (TEMPLATE_FIELDS - %w[
  requires_approval delivery_address billing_address
] + %w[globally_visible]).freeze

QUESTION_FIELDS = %w[question type required multiple_choices choices].freeze

def dump_questions(questions)
  questions.map do |q|
    QUESTION_FIELDS.each_with_object({}) do |field, hash|
      value = q.public_send(field)
      hash[field] = value unless value.nil?
    end
  end
end

def dump_template(event, fields)
  template = fields.each_with_object({}) do |field, hash|
    value = event.public_send(field)
    hash[field] = value unless value.nil?
  end
  template["application_questions"] = dump_questions(event.application_questions)
  template["admin_questions"] = dump_questions(event.admin_questions)
  template
end

namespace :bienenschweiz do
  namespace :event_kind_template do
    desc "Print an existing course as event kind template YAML.\n" \
         "Usage: rake bienenschweiz:event_kind_template:dump[COURSE_ID] \\\n" \
         "         > ../hitobito_bienenschweiz/config/event_kind_templates/<kind_id>.yml"
    task :dump, [:course_id] => :environment do |_, args|
      course_id = args[:course_id] or
        abort "Usage: rake bienenschweiz:event_kind_template:dump[COURSE_ID]"

      course = Event::Course.find(course_id)
      abort "Course #{course_id} has no kind assigned." unless course.kind_id

      # Only the YAML goes to stdout so it can be redirected into the template
      # file, the hint where it belongs goes to stderr.
      puts dump_template(course, TEMPLATE_FIELDS).to_yaml
      warn "Redirect this output to config/event_kind_templates/#{course.kind_id}.yml"
    end
  end

  namespace :event_template do
    desc "Print an existing non-course event as event template YAML.\n" \
         "Usage: rake bienenschweiz:event_template:dump[EVENT_ID] \\\n" \
         "         > ../hitobito_bienenschweiz/config/event_templates/<slug>.yml"
    task :dump, [:event_id] => :environment do |_, args|
      event_id = args[:event_id] or
        abort "Usage: rake bienenschweiz:event_template:dump[EVENT_ID]"

      event = Event.find(event_id)
      unless event.instance_of?(Event)
        abort "Event #{event_id} is a #{event.class}, not a plain event."
      end

      template = {"label" => event.name}.merge(dump_template(event, EVENT_TEMPLATE_FIELDS))

      puts template.to_yaml
      warn "Redirect this output to config/event_templates/#{event.name.to_s.parameterize}.yml"
    end
  end
end
