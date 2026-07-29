# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class InspectionMailer < ApplicationMailer
  # rubocop:disable Rails/EnvironmentVariableAccess
  INSPECTION_REPLY_TO_EMAIL = ENV["INSPECTION_REPLY_TO_EMAIL"]
  INSPECTION_BCC_EMAIL = ENV["INSPECTION_BCC_EMAIL"]
  CANTONAL_INSPECTOR_CC_EMAIL = ENV["CANTONAL_INSPECTOR_CC_EMAIL"]
  CANTONAL_INSPECTOR_BCC_EMAIL = ENV["CANTONAL_INSPECTOR_BCC_EMAIL"]
  SECRETARY_EMAIL = ENV["SECRETARY_EMAIL"]
  APP_NOTIFICATIONS_EMAIL = ENV["APP_NOTIFICATIONS_EMAIL"]
  CHECKLIST_MEMBER_EMAIL = ENV["CHECKLIST_MEMBER_EMAIL"]
  CHECKLIST_INSPECTOR_EMAIL = ENV["CHECKLIST_INSPECTOR_EMAIL"]
  PRINTER_EMAIL = ENV["PRINTER_EMAIL"]
  # rubocop:enable Rails/EnvironmentVariableAccess

  default reply_to: INSPECTION_REPLY_TO_EMAIL

  def sectional_inspection_reminder_mail(reminder)
    xlsx = render_to_string handlers: [:axlsx], formats: [:xlsx],
      template: "structure_exports/attachment_export",
      locals: {members: reminder.related_member_data}
    attachments["Siegelimker Sektion #{reminder.group.name}.xlsx"] =
      {mime_type: Mime[:xlsx], content: xlsx}

    mail to: reminder.inspector_emails,
      cc: reminder.president_emails,
      bcc: INSPECTION_BCC_EMAIL,
      subject: "Automatischer Mail-Versand der Listen Siegelimker - Sektion: #{reminder.group.name}"
  end

  def cantonal_inspection_reminder_mail(reminder)
    xlsx = render_to_string handlers: [:axlsx], formats: [:xlsx],
      template: "structure_exports/attachment_export",
      locals: {members: reminder.related_member_data}
    attachments["Siegelimker Kanton #{reminder.group.name}.xlsx"] =
      {mime_type: Mime[:xlsx], content: xlsx}

    mail to: reminder.inspector_emails,
      cc: CANTONAL_INSPECTOR_CC_EMAIL,
      bcc: "#{INSPECTION_BCC_EMAIL}, #{CANTONAL_INSPECTOR_BCC_EMAIL}",
      subject: "Automatischer Mail-Versand der Listen Siegelimker - Kanton: #{reminder.group.name}"
  end

  def address_update_request_mail(inspector, member, changes)
    @inspector = inspector
    @member = member
    @changes = changes
    mail to: APP_NOTIFICATIONS_EMAIL,
      subject: "Antrag für eine Adressänderung von Siegelimker #{member.full_name}"
  end

  def blank_inspection_info_mailer(new_member, qcontrol_id)
    @qcontrol = Qcontrol.find(qcontrol_id)
    @inspector = @qcontrol.inspector
    @new_member = new_member
    @intern_structure = @qcontrol.group
    @member_columns = %i[first_name last_name email]
    # TODO: implement
    # @member_columns = %i[first_name last_name email phone mobile street house_no zip location]
    # attachments[I18n.t('checklist_attachment_name')] =
    #   PdfService.render(:blank_checklist, @qcontrol, @new_member)
    mail to: APP_NOTIFICATIONS_EMAIL, subject: I18n.t("blank_inspection_info.subject")
  end

  # email sent to beekeeper and inspector when a quality control is created
  # and is passed /partially passed
  def beekeeper_and_inspector_checklist_pdf_mailer(qcontrol_id, copy_to_secretary)
    load_qcontrol_and_attach(qcontrol_id)
    cc = [inspector_email]
    cc << APP_NOTIFICATIONS_EMAIL if copy_to_secretary
    mail to: member_email, cc: cc, subject: I18n.t("beekeeper_and_inspector_checklist.subject")
  end

  # email sent to inspector when a quality control is created and is passed / partially passed
  # and the beekeeper does not have an email address
  def only_inspector_checklist_pdf_mailer(qcontrol_id, copy_to_secretary)
    load_qcontrol_and_attach(qcontrol_id)
    cc = copy_to_secretary ? APP_NOTIFICATIONS_EMAIL : nil
    mail to: inspector_email, cc: cc, subject: I18n.t("only_inspector_checklist.subject")
  end

  def inspection_not_necessary_mailer(qcontrol_id)
    @qcontrol = Qcontrol.find(qcontrol_id)
    mail to: APP_NOTIFICATIONS_EMAIL, subject: I18n.t("inspection_not_necessary.subject")
  end

  def inspection_failed_mailer(qcontrol_id)
    @qcontrol = Qcontrol.find(qcontrol_id)
    mail to: APP_NOTIFICATIONS_EMAIL,
      subject: I18n.t("inspection_failed.subject", name: @qcontrol.person.full_name)
  end

  def print_certificate_and_letter(qcontrol_id)
    @qcontrol = Qcontrol.find(qcontrol_id)
    @member = @qcontrol.person
    name = "#{I18n.t("inspection_mailer.print_certificate_and_letter.attachment_name",
      name: @member.full_name)}.pdf"
    attachments[name] = render_certificate_and_letter(@qcontrol)
    mail to: PRINTER_EMAIL,
      subject: I18n.t("inspection_mailer.print_certificate_and_letter.subject",
        name: @member.full_name)
  end

  private

  def render_certificate_and_letter(qcontrol)
    pdf = Export::Pdf::Qcontrol::CertificateLetter.new(qcontrol)
    pdf.draw_all
    combined_pdf = Export::Pdf::Qcontrol::Certificate.new(qcontrol, document: pdf.document)
    combined_pdf.render
  end

  def load_qcontrol_and_attach(qcontrol_id)
    @qcontrol = Qcontrol.find(qcontrol_id)
    attachments[I18n.t("checklist_attachment_name")] =
      Export::Pdf::Qcontrol::Checklist.new(@qcontrol).render
  end

  def member_email
    CHECKLIST_MEMBER_EMAIL || @qcontrol.person.email
  end

  def inspector_email
    CHECKLIST_INSPECTOR_EMAIL || @qcontrol.inspector.email
  end
end
