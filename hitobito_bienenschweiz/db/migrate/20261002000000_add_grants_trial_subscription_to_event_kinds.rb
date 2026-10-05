# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class AddGrantsTrialSubscriptionToEventKinds < ActiveRecord::Migration[8.0]
  def up
    add_column :event_kinds, :grants_trial_subscription, :boolean, default: false, null: false

    # Basiskurs Imkern (Grundkurs)
    execute("UPDATE event_kinds SET grants_trial_subscription = TRUE WHERE abbreviation = 'BI'")
  end

  def down
    remove_column :event_kinds, :grants_trial_subscription
  end
end
