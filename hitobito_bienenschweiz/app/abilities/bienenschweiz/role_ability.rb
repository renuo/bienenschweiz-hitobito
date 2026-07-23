# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Bienenschweiz::RoleAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Group

  on(Role) do
    permission(:layer_contacts)
      .may(:show, :create, :create_in_subgroup, :update, :destroy, :terminate)
      .in_same_layer_if_active
    general(:create, :update, :destroy).modify_beekeeper_permission_only_of_admin
  end

  def modify_beekeeper_permission_only_of_admin
    beekeeper_role? ? if_admin : true
  end

  def beekeeper_role?
    subject.type&.safe_constantize == Group::Siegelimker::Siegelimker
  end
end
