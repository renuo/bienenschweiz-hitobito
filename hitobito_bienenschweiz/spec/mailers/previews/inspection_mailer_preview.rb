# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class InspectionMailerPreview < ActionMailer::Preview
  def print_certificate_and_letter
    qcontrol = Qcontrol.where.not(person: nil).last
    InspectionMailer.print_certificate_and_letter(qcontrol.id)
  end

  def beekeeper_and_inspector_checklist_pdf_mailer
    qcontrol = Qcontrol.where.not(person: nil).last
    InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(qcontrol.id, false)
  end

  def only_inspector_checklist_pdf_mailer
    qcontrol = Qcontrol.where.not(person: nil).last
    InspectionMailer.only_inspector_checklist_pdf_mailer(qcontrol.id, false)
  end

  def sectional_inspection_reminder_mail
    sektion = Group::Sektion.first
    InspectionMailer.sectional_inspection_reminder_mail(reminder_for(sektion))
  end

  def cantonal_inspection_reminder_mail
    kantonalverband = Group::Kantonalverband.first
    InspectionMailer.cantonal_inspection_reminder_mail(reminder_for(kantonalverband))
  end

  private

  def reminder_for(group)
    InspectionService.new.send(:inspection_reminder, group)
  end
end
