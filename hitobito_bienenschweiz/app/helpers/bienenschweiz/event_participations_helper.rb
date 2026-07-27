# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::EventParticipationsHelper
  # The bulk answers edit page should respect whatever participant_type
  # filter is active on the participations index, so it edits the same
  # people the button was clicked from. Only that filter key is forwarded.
  def bulk_answers_filter_params
    return {} unless params.dig(:filters, :participant_type)

    {participant_type: params.dig(:filters, :participant_type)}
  end
end
