# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class ConvertSchnupperAbosToGratisAbos < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      UPDATE magazine_subscriptions SET subscription_type = 'gratis_abo'
      WHERE subscription_type = 'schnupper_abo'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
