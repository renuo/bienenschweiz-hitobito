# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class FeedbackRoundAbility < AbilityDsl::Base
  on(FeedbackRound) do
    permission(:any).may(:create, :read, :destroy, :report).if_event_editable
    class_side(:index_report).if_admin
  end

  # Anyone allowed to edit the course itself may manage its feedback rounds,
  # including the single-course report. Delegating to the actual Event
  # permission (rather than re-declaring the group/layer/leader tiers here)
  # keeps this in sync with EventAbility.
  def if_event_editable
    Ability.new(user).can?(:update, subject.event)
  end

  # The cross-course aggregate report is not scoped to a single course's
  # editors, so it is restricted to the org-wide administrator role instead.
  def if_admin
    role_type?(Group::Dachverband::AdministratorBienenSchweiz)
  end
end
