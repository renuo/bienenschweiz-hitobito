# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class InspectionMailerPreview < ActionMailer::Preview
  def print_certificate_and_letter
    qcontrol = Qcontrol.last
    InspectionMailer.print_certificate_and_letter(qcontrol.id)
  end
end
