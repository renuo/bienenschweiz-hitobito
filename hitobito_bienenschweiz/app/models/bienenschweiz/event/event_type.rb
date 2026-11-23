# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Anlasstyp: mandatory for plain events, not used by courses.
module Bienenschweiz::Event::EventType
  extend ActiveSupport::Concern

  EVENT_TYPES = %w[public online internal].freeze

  included do
    include I18nEnums

    i18n_enum :event_type, EVENT_TYPES
    validates :event_type, presence: true, if: -> { used_attributes.include?(:event_type) }
  end
end
