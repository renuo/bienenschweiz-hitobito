# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class ExternalInvoiceAbility < AbilityDsl::Base
  on(ExternalInvoice) do
    class_side(:index).if_admin_or_root_token
    permission(:any).may(:show, :update).if_admin_or_root_token
  end

  def if_admin_or_root_token
    role_type?(Group::Dachverband::AdministratorBienenSchweiz) || root_token?
  end

  private

  def root_token?
    token = user.service_token
    token.present? && token.layer.root? && token.permission == "layer_and_below_full"
  end
end
