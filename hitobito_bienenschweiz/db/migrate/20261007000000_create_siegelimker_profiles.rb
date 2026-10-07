# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class CreateSiegelimkerProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :siegelimker_profiles do |t|
      t.belongs_to :person, null: false, index: {unique: true}
      t.boolean :public_profile, null: false, default: false
      t.string :title
      t.text :description
      t.integer :siegelimker_since
      t.string :website
      t.boolean :public_offer, null: false, default: false
      t.string :honey_availability, null: false, default: "not_offered"
      t.string :propolis_availability, null: false, default: "not_offered"
      t.string :pollen_availability, null: false, default: "not_offered"
      t.string :queens_availability, null: false, default: "not_offered"
      t.string :wax_availability, null: false, default: "not_offered"
      t.string :bee_location_1
      t.string :bee_location_2
      t.string :bee_location_3
      t.string :bee_location_4
      t.string :bee_location_5
      t.text :further_information
      t.decimal :lat, precision: 11, scale: 9
      t.decimal :lng, precision: 12, scale: 9

      t.timestamps
    end

    create_table :siegelimker_sales_points do |t|
      t.belongs_to :siegelimker_profile, null: false
      t.string :name
      t.string :address
      t.string :email
      t.string :phone

      t.timestamps
    end
  end
end
