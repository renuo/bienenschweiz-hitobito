# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class MemoAbility < AbilityDsl::Base
  on(Memo) do
    class_side(:index).if_admin
    permission(:any).may(:show, :create, :update, :destroy).if_admin
  end

  def if_admin
    role_type?(Group::Dachverband::AdministratorBienenSchweiz)
  end
end
