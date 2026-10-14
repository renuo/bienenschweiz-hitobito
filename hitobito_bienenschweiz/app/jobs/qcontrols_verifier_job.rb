# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Alerts the secretary about qcontrols changed during the last day for which no
# fee could be created in KAS.
class QcontrolsVerifierJob < RecurringJob
  run_every 1.day

  private

  def perform_internal
    qcontrols = Qcontrol.from_yesterday.needs_fee_creation
    QcontrolsMailer.without_fee_alert(qcontrols).deliver_now if qcontrols.exists?
  end

  def next_run
    # Sets next run to 07:00 of next day
    Time.zone.tomorrow.at_beginning_of_day.change(hour: 7).in_time_zone
  end
end
