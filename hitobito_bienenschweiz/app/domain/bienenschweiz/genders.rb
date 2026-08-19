# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz
  # Registers the additional gender option "divers" on Person. The gender column
  # holds a single character, so the core's %w[m w] is extended with "d".
  module Genders
    ADDITIONAL = "d"

    class << self
      def register!
        # to_prepare runs on every reload cycle, but Person::GENDERS is only
        # reset when Person itself is reloaded, so appending must be idempotent.
        ::Person::GENDERS << ADDITIONAL unless ::Person::GENDERS.include?(ADDITIONAL)

        # The setter captured the list of possible values at class definition
        # time, redefine it so imports accept the translated value as well.
        ::Person.i18n_setter :gender, (::Person::GENDERS + [nil])
      end
    end
  end
end
