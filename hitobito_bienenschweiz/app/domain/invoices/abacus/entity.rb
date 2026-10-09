# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas.

module Invoices
  module Abacus
    class Entity
      attr_reader :entity, :errors

      class << self
        def wrap(entity)
          return entity if entity.is_a?(self)

          new(entity)
        end
      end

      def initialize(entity)
        @entity = entity
        @errors = {}
      end

      # Returns false if the entity is invalid for abacus
      def valid?
        @errors = {}
        validate
        @errors.blank?
      end

      def validate
        # implement in subclass
      end

      def error_messages
        errors.map do |attr, key|
          ActiveModel::Error.new(entity, attr, key).full_message
        end
      end
    end
  end
end
