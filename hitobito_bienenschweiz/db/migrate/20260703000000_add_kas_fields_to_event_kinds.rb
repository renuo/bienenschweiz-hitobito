# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class AddKasFieldsToEventKinds < ActiveRecord::Migration[8.0]
  def change
    add_column :event_kinds, :kas_fee_code, :string
    add_column :event_kinds, :kas_fixed_fee, :boolean, default: false, null: false
  end
end
