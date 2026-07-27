// Copyright (c) 2012-2026, BienenSchweiz. This file is part of
// hitobito_bienenschweiz and licensed under the Affero General Public License version 3
// or later. See the COPYING file at the top-level directory or at
// https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

// Note: no class fields or optional chaining — wagon JS is not transpiled by Babel.
import { stimulus } from "controllers";
import TomSelectController from "controllers/tom_select_controller";

// Core's tom-select controller never tears down its TomSelect instance on
// disconnect. When Turbo Drive reconnects the same element (e.g. restoring a
// page from cache), TomSelect throws "already initialized on this element".
// Register the same behavior under a wagon-namespaced identifier with a
// disconnect() that destroys the instance first.
class SafeTomSelectController extends TomSelectController {
  disconnect() {
    if (this.tom) {
      this.tom.destroy();
      this.tom = undefined;
    }
  }
}

stimulus.register("bienenschweiz-tom-select", SafeTomSelectController);
