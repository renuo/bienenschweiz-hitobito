# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::Event::Question
  extend ActiveSupport::Concern

  EVERYONE = "everyone"
  LEADERS = "leaders"
  PARTICIPANTS = "participants"
  RELEVANCES = [EVERYONE, LEADERS, PARTICIPANTS].freeze

  included do
    i18n_enum :relevance, RELEVANCES
  end

  class_methods do
    # Restricts to questions relevant for the given participant_type filter value
    # (as used by Event::ParticipationFilter::List / the bulk answers controller):
    # "participants"/"teamers" narrow to the matching relevance, anything else
    # (nil, "all", a custom role label) leaves the scope untouched.
    def relevant_for_filter(participant_type)
      case participant_type
      when "participants"
        where(relevance: [EVERYONE, PARTICIPANTS])
      when "teamers"
        where(relevance: [EVERYONE, LEADERS])
      else
        all
      end
    end
  end

  def relevant_for?(participation)
    case relevance
    when LEADERS
      # Anyone with a role that isn't a normal participant counts as a leader
      # here (leaders, assistant leaders, cooks, helpers, treasurers, ...).
      participation.roles.any? { |role| !role.class.participant? }
    when PARTICIPANTS
      participation.roles.any? { |role| role.class.participant? }
    else
      true
    end
  end
end
