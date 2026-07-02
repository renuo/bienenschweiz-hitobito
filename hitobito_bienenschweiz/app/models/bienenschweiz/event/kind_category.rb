# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz::Event::KindCategory
  extend ActiveSupport::Concern

  included do
    before_validation { self.layer_group_type = nil if layer_group_type.blank? }
    validates :layer_group_type, inclusion: {in: ->(_) { layer_group_types }}, allow_nil: true
  end

  class_methods do
    def layer_group_types
      Group.all_types.select(&:layer).map(&:sti_name)
    end
  end
end
