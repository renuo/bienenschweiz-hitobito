# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

# Add a qcontrol with randomly filled out answers for every Siegelimker
# that does not have one yet.
current_questions = QualityControlQuestion
  .joins(:quality_control_section)
  .where(quality_control_sections: {version: QualityControlSection.version})
  .order(:id)

Role.where(type: Group::Siegelimker::Siegelimker.sti_name)
  .includes(:person, :group).find_each do |role|
  person = role.person
  next if person.nil? || person.qcontrols.exists?

  sektion = role.group.parent
  inspector = Person.joins(:roles).where(roles: {
    type: Group::Kader::FachpersonProdukte.sti_name,
    group_id: sektion.children.where(type: Group::Kader.sti_name)
  }).first

  answers = current_questions.map do |question|
    fulfilled = %w[passed passed passed passed partially_passed not_passed].sample
    {
      quality_control_question_id: question.id,
      fulfilled: fulfilled,
      notes: (Faker::Lorem.sentence if fulfilled != "passed"),
      deadline_at: ((Time.zone.today + rand(10..60).days) if fulfilled == "partially_passed")
    }
  end

  person.qcontrols.create!(
    group: sektion,
    inspector: inspector,
    control_date: Faker::Date.between(from: 2.years.ago, to: Time.zone.today),
    certificate_printed: true, # the notification callbacks must not fire for seeds
    quality_control_answers_attributes: answers
  )
end

Group.where(type: Group::Siegelimker.sti_name).each do |group|
  answers = current_questions.map do |question|
    fulfilled = %w[passed passed passed passed partially_passed not_passed].sample
    {
      quality_control_question_id: question.id,
      fulfilled: fulfilled,
      notes: (Faker::Lorem.sentence if fulfilled != "passed"),
      deadline_at: ((Time.zone.today + rand(10..60).days) if fulfilled == "partially_passed")
    }
  end
  sektion = group.parent
  inspector = Person.joins(:roles).where(roles: {
    type: Group::Kader::FachpersonProdukte.sti_name,
    group_id: sektion.children.where(type: Group::Kader.sti_name)
  }).first
  Qcontrol.create!(
    group: sektion,
    inspector: inspector,
    control_date: Faker::Date.between(from: 2.years.ago, to: Time.zone.today),
    certificate_printed: true, # the notification callbacks must not fire for seeds
    quality_control_answers_attributes: answers
  )
end
