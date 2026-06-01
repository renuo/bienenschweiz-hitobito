# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class InspectionService
  PERIOD = 4.years
  TIMEFRAME = 6.months
  # Overdue, due soon and recently checked functionality removed, due to lack of use

  def deliver_inspection_reminders
    mails = inspection_reminder_mails
    log_and_deliver(mails)
  end

  def retry_failed_inspection_reminder(index)
    mails = inspection_reminder_mails
    log_and_deliver([mails[index]], no_sleep: true)
  end

  def build_structure_mails(scope, mailer)
    filtered_structures = scope.reject do |structure|
      excluded_intern_structure_ids.include?(structure.id)
    end
    filtered_structures.map do |structure|
      reminder = inspection_reminder(structure)
      if reminder.any?
        OpenStruct.new(reminder: reminder,
          mail: InspectionMailer.public_send(mailer, reminder))
      end
    end
  end

  def excluded_intern_structure_ids
    @excluded_intern_structure_ids ||= InternStructure.mailer_excluded.map do |struct|
      struct.self_and_descendants.pluck(:id)
    end.flatten
  end

  private

  def inspection_reminder_mails
    (build_structure_mails(InternStructure.verband, :cantonal_inspection_reminder_mail) +
      build_structure_mails(InternStructure.sektion, :sectional_inspection_reminder_mail)
    ).compact
  end

  # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize
  def log_and_deliver(reminder_mails, no_sleep: false)
    Rails.logger
      .info "Going to send #{reminder_mails.size} emails to the following email addresses:"
    reminder_mails.each do |mail|
      Rails.logger.info formatted_intern_structure(mail.reminder)
    end
    reminder_mails.each_with_index.map do |reminder_mail, index|
      Rails.logger.info(
        "Sending email (index #{index}/#{reminder_mails.size - 1}) to \
#{formatted_intern_structure(reminder_mail.reminder)}"
      )
      begin
        # since the mail cannot be run in a queue (because cannot be serialized easily)
        # we use a try/catch block
        unless Rails.env.test? || no_sleep
          Rails.logger.info "Waiting 5 minutes to not be blocked by bluewin"
          sleep(5.minutes)
        end
        reminder_mail.mail.deliver_now
      rescue StandardError => e
        Rails.logger
          .error "Failed to send email to #{formatted_intern_structure(reminder_mail.reminder)}"
        if defined?(Sentry)
          Sentry.capture_exception(e, extra: {failed_index: index})
        else
          throw e
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize

  def inspection_reminder(intern_structure)
    case intern_structure.structure_type
    when "sektion"
      members = intern_structure.members.siegel_imkers.alive
      inspectors = intern_structure.members.inspectors.alive.distinct
    else
      members = intern_structure.members_including_substructures.alive.siegel_imkers
      inspectors = intern_structure.members.honey_chairmen.alive.distinct
    end

    InternStructureInspectionReminder.new(intern_structure, inspectors, members)
  end

  def formatted_intern_structure(reminder)
    intern_structure = reminder.intern_structure
    "#{intern_structure.name} (#{intern_structure.kanton}): #{reminder.inspector_emails.join(",")}"
  end
end
