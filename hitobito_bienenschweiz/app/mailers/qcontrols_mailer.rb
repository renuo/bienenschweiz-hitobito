# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class QcontrolsMailer < ApplicationMailer
  # rubocop:disable Rails/EnvironmentVariableAccess
  SECRETARY_EMAIL = ENV["SECRETARY_EMAIL"]
  DEVELOPER_EMAIL = ENV["DEVELOPER_EMAIL"]
  # rubocop:enable Rails/EnvironmentVariableAccess

  def without_fee_alert(qcontrols)
    @qcontrols = qcontrols.includes(:author, :group, :person).order(:control_date).to_a
    @orphans = Qcontrol.from_yesterday.orphan
    @failed_qcontrols = @qcontrols.select(&:should_create_fee?)
    mail to: SECRETARY_EMAIL, cc: DEVELOPER_EMAIL,
      subject: t("qcontrols_mailer.without_fee_alert.subject")
  end
end
