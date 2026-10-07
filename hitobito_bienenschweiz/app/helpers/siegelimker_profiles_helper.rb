# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module SiegelimkerProfilesHelper
  # Half the height of the shown map section in degrees, keep in sync with
  # app/javascript/controllers/siegelimker_map_controller.js
  MAP_DELTA = 0.004

  def siegelimker_map_embed_url(lat, lng)
    lat = lat.to_f
    lng = lng.to_f
    bbox = [lng - (2 * MAP_DELTA), lat - MAP_DELTA, lng + (2 * MAP_DELTA), lat + MAP_DELTA]
    "https://www.openstreetmap.org/export/embed.html?" \
      "bbox=#{bbox.join(",")}&layer=mapnik&marker=#{lat},#{lng}"
  end

  def siegelimker_map_url(lat, lng)
    "https://www.openstreetmap.org/?mlat=#{lat.to_f}&mlon=#{lng.to_f}#map=17/#{lat.to_f}/#{lng.to_f}"
  end

  def siegelimker_coordinates_source(profile)
    if profile.manual_coordinates?
      t("siegelimker_profiles.coordinates_source.manual")
    elsif profile.geocoded_address.blank?
      t("siegelimker_profiles.coordinates_source.no_address")
    elsif profile.coordinates?
      t("siegelimker_profiles.coordinates_source.geocoded", address: profile.geocoded_address)
    else
      t("siegelimker_profiles.coordinates_source.not_found", address: profile.geocoded_address)
    end
  end
end
