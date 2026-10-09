# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module JsonApi
  # The website profile is readable for everybody who may read the person.
  class SiegelimkerProfileReadables
    include CanCan::Ability

    def initialize(user)
      readable_people = Person.accessible_by(PersonReadables.new(user)).unscope(:select)
      readable_profiles = SiegelimkerProfile.where(person_id: readable_people.select(:id))

      can :read, SiegelimkerProfile, id: readable_profiles.select(:id)
      can :read, SiegelimkerSalesPoint, siegelimker_profile_id: readable_profiles.select(:id)
    end
  end
end
