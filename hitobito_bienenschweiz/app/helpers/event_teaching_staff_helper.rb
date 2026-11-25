# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module EventTeachingStaffHelper
  TEACHING_STAFF_ROLE_TYPES = [
    Event::Role::Leader,
    Event::Role::AssistantLeader,
    Event::Role::Speaker
  ].freeze

  # Roles of the active Hauptleitung, Leitung and Referenten of the event,
  # ordered by role type and then by participant name.
  def event_teaching_staff_roles(event)
    Event::Role
      .joins(:participation)
      .where(type: TEACHING_STAFF_ROLE_TYPES.map(&:sti_name),
        event_participations: {event_id: event.id, active: true,
                               participant_type: Person.sti_name})
      .includes(participation: :participant)
      .sort_by do |role|
        [TEACHING_STAFF_ROLE_TYPES.index(role.class), role.participation.participant.full_name]
      end
  end
end
