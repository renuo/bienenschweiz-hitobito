# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class SiegelimkerProfilesController < CrudController
  self.nesting = Group, Person

  self.permitted_attrs = [
    :public_profile, :title, :description, :siegelimker_since, :website,
    :public_offer, *SiegelimkerProfile::PRODUCTS.map { |p| :"#{p}_availability" },
    *SiegelimkerProfile::BEE_LOCATIONS, :further_information, :lat, :lng,
    :background_image, :remove_background_image,
    sales_points_attributes: [:id, :name, :address, :email, :phone, :_destroy]
  ]

  decorates :group, :person

  prepend_before_action :parent
  before_action :assert_siegelimker
  # authorize_resource only checks the class on singular resources (no :id param)
  before_action { authorize!(action_name.to_sym, entry) }

  def update
    super(location: show_path)
  end

  private

  def find_entry
    @person.siegelimker_profile || @person.build_siegelimker_profile
  end
  alias_method :build_entry, :find_entry

  def path_args(_)
    [@group, @person, :siegelimker_profile]
  end

  def show_path
    group_person_siegelimker_profile_path(@group, @person)
  end

  def assert_siegelimker
    raise ActiveRecord::RecordNotFound unless @person.siegelimker?
  end
end
