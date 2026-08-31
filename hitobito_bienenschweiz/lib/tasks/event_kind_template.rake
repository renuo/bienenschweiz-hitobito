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

def stdout_output?(output)
  output.to_s.casecmp("stdout").zero?
end

# Writes the template to output_path, or prints it to stdout when requested.
# In stdout mode only the YAML goes to stdout so it can be piped or redirected,
# the info line goes to stderr.
def emit_template(template, output_path, output, info)
  if stdout_output?(output)
    puts template.to_yaml
    warn info
  else
    File.write(output_path, template.to_yaml)
    puts "Written to #{output_path}"
    puts info
  end
end

namespace :bienenschweiz do
  namespace :event_kind_template do
    desc "Dump an existing course as an event kind template YAML file.\n" \
         "Usage: rake bienenschweiz:event_kind_template:dump[COURSE_ID]\n" \
         "Output: config/event_kind_templates/<kind_id>.yml\n" \
         "Pass 'stdout' as second argument to print the YAML instead of writing it:\n" \
         "  rake bienenschweiz:event_kind_template:dump[COURSE_ID,stdout]"
    task :dump, [:course_id, :output] => :environment do |_, args|
      course_id = args[:course_id] or
        abort "Usage: rake bienenschweiz:event_kind_template:dump[COURSE_ID,OUTPUT]"

      course = Event::Course.find(course_id)
      abort "Course #{course_id} has no kind assigned." unless course.kind_id

      output_path = HitobitoBienenschweiz::Wagon.root
        .join("config", "event_kind_templates", "#{course.kind_id}.yml")

      emit_template(dump_template(course, TEMPLATE_FIELDS), output_path, args[:output],
        "Kind: #{course.kind} (id=#{course.kind_id})")
    end
  end

  namespace :event_template do
    desc "Dump an existing non-course event as an event template YAML file.\n" \
         "Usage: rake bienenschweiz:event_template:dump[EVENT_ID,SLUG]\n" \
         "Output: config/event_templates/<slug>.yml\n" \
         "Pass 'stdout' as third argument to print the YAML instead of writing it:\n" \
         "  rake bienenschweiz:event_template:dump[EVENT_ID,SLUG,stdout]"
    task :dump, [:event_id, :slug, :output] => :environment do |_, args|
      event_id = args[:event_id] or
        abort "Usage: rake bienenschweiz:event_template:dump[EVENT_ID,SLUG,OUTPUT]"

      event = Event.find(event_id)
      unless event.instance_of?(Event)
        abort "Event #{event_id} is a #{event.class}, not a plain event."
      end

      slug = args[:slug].presence || event.name.to_s.parameterize
      abort "Invalid slug '#{slug}', use only [a-z0-9_-]." unless /\A[a-z0-9_-]+\z/.match?(slug)

      output_path = HitobitoBienenschweiz::Wagon.root
        .join("config", "event_templates", "#{slug}.yml")

      template = {"label" => event.name}.merge(dump_template(event, EVENT_TEMPLATE_FIELDS))

      emit_template(template, output_path, args[:output], "Label: #{event.name} (slug=#{slug})")
    end
  end
end
