# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class InspectionService
  PERIOD = 4.years
  TIMEFRAME = 6.months

  def deliver_inspection_reminders
    mails = inspection_reminder_mails
    log_and_deliver(mails)
  end

  def retry_failed_inspection_reminder(index)
    mails = inspection_reminder_mails
    log_and_deliver([mails[index]], no_sleep: true)
  end

  def build_structure_mails(scope, mailer)
    scope.filter_map do |group|
      reminder = inspection_reminder(group)
      if reminder.any?
        OpenStruct.new(reminder: reminder,
          mail: InspectionMailer.public_send(mailer, reminder))
      end
    end
  end

  private

  def inspection_reminder_mails
    (build_structure_mails(Group.where(type: Group::Kantonalverband.sti_name),
      :cantonal_inspection_reminder_mail) +
      build_structure_mails(Group.where(type: Group::Sektion.sti_name),
        :sectional_inspection_reminder_mail)).compact
  end

  # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize
  def log_and_deliver(reminder_mails, no_sleep: false)
    Rails.logger.info "Going to send #{reminder_mails.size} emails to the following email addresses:"
    reminder_mails.each do |mail|
      Rails.logger.info formatted_group(mail.reminder)
    end
    reminder_mails.each_with_index.map do |reminder_mail, index|
      Rails.logger.info(
        "Sending email (index #{index}/#{reminder_mails.size - 1}) to \
#{formatted_group(reminder_mail.reminder)}"
      )
      begin
        unless Rails.env.test? || no_sleep
          Rails.logger.info "Waiting 5 minutes to not be blocked by bluewin"
          sleep(5.minutes)
        end
        reminder_mail.mail.deliver_now
      rescue StandardError => e
        Rails.logger.error "Failed to send email to #{formatted_group(reminder_mail.reminder)}"
        if defined?(Sentry)
          Sentry.capture_exception(e, extra: {failed_index: index})
        else
          raise e
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize

  def inspection_reminder(group)
    inspectors = case group
    when Group::Sektion
      kader_groups = Group.where(type: Group::Kader.sti_name, parent_id: group.id)
      Person.joins(:roles)
        .where(roles: {type: Group::Kader::FachpersonProdukte.sti_name, group: kader_groups})
        .merge(Role.active)
        .distinct
    when Group::Kantonalverband
      vorstand_groups = Group.where(type: Group::KantonalverbandVorstand.sti_name,
        parent_id: group.id)
      Person.joins(:roles)
        .where(roles: {type: Group::KantonalverbandVorstand::Produkte.sti_name,
                       group: vorstand_groups})
        .merge(Role.active)
        .distinct
    else
      Person.none
    end

    GroupInspectionReminder.new(group, inspectors)
  end

  def formatted_group(reminder)
    "#{reminder.group.name} (#{reminder.group.canton_short}): #{reminder.inspector_emails.join(",")}"
  end
end
