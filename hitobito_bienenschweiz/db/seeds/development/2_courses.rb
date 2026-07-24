# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

# Seeds one Event::Course per Event::Kind (i.e. every course type offered by
# BienenSchweiz), each with leaders, participants and feedback rounds that
# have already been filled out with random answers.
#
# The "Basiskurs Imkern" is BienenSchweiz' flagship course and is taught
# module by module over roughly two years, so each Sektion gets its own
# Basiskurs Imkern course with 18 dates spread over that period instead of
# the handful of dates other course kinds get.

require Rails.root.join("db", "seeds", "support", "event_seeder")

srand(44)

class CourseFeedbackSeeder < EventSeeder
  BASISKURS_IMKERN = "Basiskurs Imkern"
  BASISKURS_IMKERN_DATE_COUNT = 18
  BASISKURS_IMKERN_SPAN_IN_DAYS = 730 # roughly 2 years

  def seed_all_kinds
    Event::Kind.list.find_each do |kind|
      offerer_groups(kind).each do |group|
        seed_kind_course(kind, group)
      end
    end
  end

  private

  def offerer_groups(kind)
    if basiskurs_imkern?(kind)
      Group.where(type: Group::Sektion.sti_name)
    else
      [course_offerers.sample]
    end
  end

  def course_offerers
    @course_offerers ||= Group.course_offerers.to_a
  end

  def basiskurs_imkern?(kind)
    kind.short_name == BASISKURS_IMKERN
  end

  def seed_kind_course(kind, group)
    values = event_values(group.id)
    name = "#{kind.short_name} #{group.name}"
    event = Event::Course.find_or_initialize_by(name: name)
    return event unless event.new_record?

    event.attributes = values.merge(
      name: name,
      kind_id: kind.id,
      canceled: false,
      priorization: Event::Course.used_attributes.include?(:priorization),
      requires_approval: Event::Course.used_attributes.include?(:requires_approval),
      signature: Event::Course.used_attributes.include?(:signature),
      external_applications: Event::Course.used_attributes.include?(:external_applications)
    )

    if basiskurs_imkern?(kind)
      build_basiskurs_imkern_dates(event, values[:application_opening_at] + 90.days)
    else
      build_standard_dates(event, values[:application_opening_at] + 90.days)
    end

    event.save!

    seed_questions(event)
    seed_leaders(event)
    seed_course_participants(event, basiskurs_imkern?(kind) ? 15 : 8)
    seed_feedback_rounds(event)

    event
  end

  def build_standard_dates(event, date)
    rand(1..2).times do
      event.dates.build(label: "Vorabend", start_at: date, finish_at: date + rand(2..4).hours)
      date += rand(7..21).days
    end
    event.dates.build(label: event.class.label, start_at: date, finish_at: date + rand(1..2).days)
  end

  def build_basiskurs_imkern_dates(event, date)
    step = BASISKURS_IMKERN_SPAN_IN_DAYS.to_f / (BASISKURS_IMKERN_DATE_COUNT - 1)

    BASISKURS_IMKERN_DATE_COUNT.times do |i|
      start_at = date + (step * i).round.days + rand(5).days
      event.dates.build(label: "Modul #{i + 1}", start_at: start_at,
        finish_at: start_at + [3, 4, 5, 6].sample.hours)
    end
  end

  # Unlike EventSeeder#seed_participants, this activates every participation
  # right away so the participants show up in feedback rounds, courses are
  # not seeded with pending applications.
  def seed_course_participants(event, count)
    count.times do
      participation = seed_event_role(event, Event::Course::Role::Participant)
      participation.update_column(:active, true) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def seed_feedback_rounds(event)
    author = leader_person(event) || Person.first

    %w[intermediate final].each do |kind|
      round = FeedbackRound.create!(event: event, author: author, kind: kind)
      round.feedback_invitations.find_each { |invitation| seed_feedback_answers(invitation) }
    end
  end

  def leader_person(event)
    Event::Participation.joins(:roles)
      .where(event_id: event.id, event_roles: {type: Event::Role::Leader.sti_name})
      .first&.participant
  end

  def seed_feedback_answers(invitation)
    FeedbackQuestion.list.find_each do |question|
      invitation.feedback_answers.create!(
        feedback_question: question,
        question.kind.to_sym => random_feedback_value(question)
      )
    end
    invitation.update!(submitted_at: Faker::Time.between(from: 3.months.ago, to: Time.zone.now))
  end

  def random_feedback_value(question)
    case question.kind
    when "rating" then rand(1..5)
    when "yes_no" then [true, false].sample
    when "text" then Faker::Lorem.sentence
    end
  end
end

CourseFeedbackSeeder.new.seed_all_kinds
