# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# validates_by_schema generates presence + numericality validators for null:false integer
# columns, but both fail for an integer array column: [] fails presence (blank?),
# and [year] fails numericality (not a number). Prepend this module to clear those
# validators; the DB NOT NULL DEFAULT '{}' constraint is sufficient.
#
# Must be a plain Ruby module (not ActiveSupport::Concern) so that self.prepended fires
# independently for each class even when they share an inheritance chain.
module Bienenschweiz::ClearsArrayColumnValidators
  ATTR = "kas_instructor_fees_created_years"

  def self.prepended(base)
    super
    base._validators[ATTR.to_sym].clear
    base._validate_callbacks
      .select { |cb| cb.filter.respond_to?(:attributes) && cb.filter.attributes.include?(ATTR) }
      .each { |cb| base._validate_callbacks.delete(cb) }
  end
end
