// Copyright (c) 2026, BienenSchweiz. This file is part of
// hitobito_bienenschweiz and licensed under the Affero General Public License version 3
// or later. See the COPYING file at the top-level directory or at
// https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["type", "gifter"];

  connect() {
    this.update();
  }

  update() {
    const gift = this.typeTarget.value === "geschenk_abo";
    this.gifterTarget.classList.toggle("hidden", !gift);
    this.gifterTarget.querySelector("input:not([type=hidden])").required = gift;
    if (!gift) {
      this.gifterTarget.querySelectorAll("input").forEach((input) => {
        input.value = "";
      });
    }
  }
}
