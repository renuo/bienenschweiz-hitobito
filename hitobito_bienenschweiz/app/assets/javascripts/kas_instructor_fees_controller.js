// Copyright (c) 2012-2026, BienenSchweiz. This file is part of
// hitobito_bienenschweiz and licensed under the Affero General Public License version 3
// or later. See the COPYING file at the top-level directory or at
// https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

// Note: no class fields or optional chaining — wagon JS is not transpiled by Babel.
import { stimulus, Controller } from "controllers";

class KasInstructorFeesController extends Controller {
  static get targets() {
    return ["amount", "yearTotal", "submitButton"];
  }

  static get values() {
    return { budget: Number };
  }

  connect() {
    this.recalculate();
  }

  recalculate() {
    var totals = {};
    this.amountTargets.forEach(function (input) {
      var year = input.dataset.year;
      var amount = parseFloat(input.value) || 0;
      totals[year] = (totals[year] || 0) + amount;
    });

    var budget = this.budgetValue;
    var overBudget = false;
    this.yearTotalTargets.forEach(function (el) {
      var year = el.dataset.year;
      var total = totals[year] || 0;
      el.textContent = "CHF " + total.toFixed(2);
      el.classList.remove("text-danger", "text-success", "text-muted", "fw-bold");
      if (total > budget) {
        el.classList.add("text-danger", "fw-bold");
        overBudget = true;
      } else if (total > 0) {
        el.classList.add("text-success");
      } else {
        el.classList.add("text-muted");
      }
    });

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = overBudget;
    }
  }
}

stimulus.register("kas-instructor-fees", KasInstructorFeesController);
