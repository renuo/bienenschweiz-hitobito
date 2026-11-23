# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Anlasstyp for plain events. Courses (and other event subclasses) leave it empty,
# so there is no NOT NULL constraint and no default; presence is validated on Event.
class AddEventTypeToEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :event_type, :string
    execute "UPDATE events SET event_type = 'public' WHERE type IS NULL OR type = 'Event'"
  end

  def down
    remove_column :events, :event_type
  end
end
