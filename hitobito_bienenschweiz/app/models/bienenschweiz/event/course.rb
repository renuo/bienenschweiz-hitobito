# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz::Event::Course
  extend ActiveSupport::Concern
  prepended do
    self.role_types = [Event::Role::Leader,
      Event::Role::AssistantLeader,
      Event::Role::Helper,
      Event::Role::Speaker,
      Event::Course::Role::Participant]
    self.used_attributes -= [:state]
    self.used_attributes += [:canceled, :delivery_address, :billing_address,
                             :diploma_location, :diploma_issued_at, :diploma_only_leader]

    before_save :recalc_number
  end

  def state
    I18n.t(state_label, scope: "event_states")
  end

  def state_label
    if canceled?
      :canceled
    elsif application_closing_at && application_closing_at < Date.current
      :expired
    elsif maximum_participants && maximum_participants <= participations.count
      :full
    else
      :open
    end
  end

  def recalc_number
    self.number = "#{kind.abbreviation}-#{groups.map(&:code).join("/")}-#{start_at.year}"
  end
end
