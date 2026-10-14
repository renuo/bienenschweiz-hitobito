# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class QcontrolsMailerPreview < ActionMailer::Preview
  def without_fee_alert
    QcontrolsMailer.without_fee_alert(Qcontrol.needs_fee_creation.limit(10))
  end
end
