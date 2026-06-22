# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class SupervisionAbility < AbilityDsl::Base
  on(Supervision) do
    class_side(:index).if_admin_or_supervisor
    # :show instead of :read on purpose: a (block based) :read rule would also
    # grant the class side :index check to everybody
    permission(:any).may(:show, :create, :destroy).if_admin_or_supervisor
  end

  def if_admin_or_supervisor
    role_type?(Group::Dachverband::AdministratorBienenSchweiz,
      Group::ThemenbezogeneKontakte::Supervisor)
  end
end
