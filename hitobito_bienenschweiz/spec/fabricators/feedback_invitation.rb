# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

Fabricator(:feedback_invitation) do
  feedback_round { Fabricate(:feedback_round) }
  participation do |attrs|
    Fabricate(:event_participation, event: attrs[:feedback_round].event, active: true)
  end
end
