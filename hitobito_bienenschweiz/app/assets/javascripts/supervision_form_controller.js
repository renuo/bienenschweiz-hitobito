// Copyright (c) 2012-2026, BienenSchweiz. This file is part of
// hitobito_bienenschweiz and licensed under the Affero General Public License version 3
// or later. See the COPYING file at the top-level directory or at
// https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

import { stimulus, Controller } from "controllers";

// Only show the results belonging to the selected supervision kind and
// disable the supervisor selection for feedbacks.
// Note: wagon files are not processed by babel, so this file must stick to
// syntax webpack can parse itself (no class fields, no optional chaining).
class SupervisionFormController extends Controller {
  static get targets() {
    return ["kind", "result", "supervisor"];
  }

  switchKind() {
    const kind = this.kindTarget.value;
    const options = Array.from(this.resultTarget.options);
    options.forEach((option) => {
      option.hidden = option.dataset.kind !== kind;
    });
    const firstVisible = options.find((option) => !option.hidden);
    this.resultTarget.value = firstVisible ? firstVisible.value : "";
    this.supervisorTarget.value = null;
    this.supervisorTarget.disabled = kind !== "supervision";
  }
}

stimulus.register("supervision-form", SupervisionFormController);
