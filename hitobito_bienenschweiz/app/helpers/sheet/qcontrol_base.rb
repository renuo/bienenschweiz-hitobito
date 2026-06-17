# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Sheet
  class QcontrolBase < Base
    def left_nav?
      true
    end

    def render_left_nav
      view.render("shared/qcontrol_left_nav")
    end
  end
end
