/*
 * Copyright (c) 2026, BienenSchweiz. This file is part of
 * hitobito_bienenschweiz and licensed under the Affero General Public License version 3
 * or later. See the COPYING file at the top-level directory or at
 * https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz
 */

import { Controller } from "@hotwired/stimulus";

// Keep in sync with SiegelimkerProfilesHelper::MAP_DELTA
const MAP_DELTA = 0.004;

// Moves the map marker to the entered coordinates so they can be verified before saving.
// Note: no class fields or optional chaining — wagon JS is not transpiled by Babel.
export default class extends Controller {
  static get targets() {
    return ["lat", "lng", "map", "frame", "link"];
  }

  update() {
    const lat = parseFloat(this.latTarget.value);
    const lng = parseFloat(this.lngTarget.value);
    const valid = !isNaN(lat) && !isNaN(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180;

    this.mapTarget.hidden = !valid;
    if (!valid) return;

    const bbox = [lng - 2 * MAP_DELTA, lat - MAP_DELTA, lng + 2 * MAP_DELTA, lat + MAP_DELTA];
    this.frameTarget.src = "https://www.openstreetmap.org/export/embed.html?bbox=" +
      bbox.join(",") + "&layer=mapnik&marker=" + lat + "," + lng;
    this.linkTarget.href = "https://www.openstreetmap.org/?mlat=" + lat + "&mlon=" + lng +
      "#map=17/" + lat + "/" + lng;
  }
}
