# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class DiplomaMailer < ApplicationMailer
  PRINTER_EMAIL = ENV["PRINTER_EMAIL"] # rubocop:disable Rails/EnvironmentVariableAccess

  def order(event)
    @event = event
    pdf = Export::Pdf::Event::Diploma.new(event).render
    attachments[Export::Pdf::Event::Diploma.filename(event)] =
      {mime_type: "application/pdf", content: pdf}
    mail(
      to: PRINTER_EMAIL,
      subject: I18n.t("diploma_mailer.order.subject",
        name: event.name,
        date: formatted_date(event))
    )
  end

  private

  def formatted_date(event)
    event.diploma_issued_at ? I18n.l(event.diploma_issued_at, format: :long) : "-"
  end
end
