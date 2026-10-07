# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class SiegelimkerProfileResource < ApplicationResource
  self.readable_class = JsonApi::SiegelimkerProfileReadables
  self.acceptable_scopes += %w[people]

  with_options writable: false do
    attribute :person_id, :integer
    attribute :public_profile, :boolean
    attribute :title, :string
    attribute :description, :string
    attribute :siegelimker_since, :integer
    attribute :website, :string
    attribute :public_offer, :boolean
    SiegelimkerProfile::PRODUCTS.each do |product|
      attribute :"#{product}_availability", :string
    end
    SiegelimkerProfile::BEE_LOCATIONS.each { |attr| attribute attr, :string }
    attribute :further_information, :string
    attribute :lat, :float
    attribute :lng, :float
    attribute :background_image, :string, sortable: false, filterable: false do
      if @object.background_image.attached?
        Rails.application.routes.url_helpers
          .rails_blob_url(@object.background_image, **context.url_options)
      end
    end
    attribute :updated_at, :datetime
  end

  belongs_to :person, writable: false
  has_many :sales_points, resource: SiegelimkerSalesPointResource, writable: false,
    foreign_key: :siegelimker_profile_id
end
