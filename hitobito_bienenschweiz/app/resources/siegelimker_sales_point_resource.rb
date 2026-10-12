# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class SiegelimkerSalesPointResource < ApplicationResource
  self.readable_class = JsonApi::SiegelimkerProfileReadables
  self.acceptable_scopes += %w[people]

  with_options writable: false do
    attribute :siegelimker_profile_id, :integer
    attribute :name, :string
    attribute :address, :string
    attribute :email, :string
    attribute :phone, :string
  end
end
