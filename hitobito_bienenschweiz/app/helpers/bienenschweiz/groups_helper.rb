# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::GroupsHelper
  # For courses the participations tab lists all involved people (leaders and
  # participants alike), so BienenSchweiz labels it "Personen" instead of
  # "Teilnehmende" to avoid confusion with the "Teilnehmende" participant
  # filter shown inside the tab. Other event types keep the default label.
  def tab_event_participants_label(entry)
    return I18n.t("events.tabs.participants_course") if entry.is_a?(::Event::Course)

    super
  end
end
