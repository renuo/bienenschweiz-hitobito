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

QUESTION_FIELDS = %w[question type required multiple_choices choices].freeze
namespace :bienenschweiz do
  namespace :event_kind_template do
    def dump_questions(questions)
      questions.map do |q|
        QUESTION_FIELDS.each_with_object({}) do |field, hash|
          value = q.public_send(field)
          hash[field] = value unless value.nil?
        end
      end
    end

    desc "Dump an existing course as an event kind template YAML file.\n" \
         "Usage: rake bienenschweiz:event_kind_template:dump[COURSE_ID]\n" \
         "Output: config/event_kind_templates/<kind_id>.yml"
    task :dump, [:course_id] => :environment do |_, args|
      course_id = args[:course_id] or
        abort "Usage: rake bienenschweiz:event_kind_template:dump[COURSE_ID]"

      course = Event::Course.find(course_id)
      abort "Course #{course_id} has no kind assigned." unless course.kind_id

      output_path = HitobitoBienenschweiz::Wagon.root
        .join("config", "event_kind_templates", "#{course.kind_id}.yml")

      template = TEMPLATE_FIELDS.each_with_object({}) do |field, hash|
        value = course.public_send(field)
        hash[field] = value unless value.nil?
      end

      template["application_questions"] = dump_questions(course.application_questions)
      template["admin_questions"] = dump_questions(course.admin_questions)

      File.write(output_path, template.to_yaml)
      puts "Written to #{output_path}"
      puts "Kind: #{course.kind} (id=#{course.kind_id})"
    end
  end
end
