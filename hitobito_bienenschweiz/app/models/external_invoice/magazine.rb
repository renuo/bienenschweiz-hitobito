# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Yearly invoice of a MagazineSubscription. The first period is invoiced by
# the shop in Abacus, hitobito invoices the following periods.
class ExternalInvoice::Magazine < ExternalInvoice
  after_update :terminate_subscription, if: :state_changed_to_cancelled?

  def invoice_kind
    :magazine_subscription
  end

  private

  def state_changed_to_cancelled?
    saved_change_to_state? && cancelled?
  end

  # Abacus cancels the invoice when it has not been paid. Subscriptions that
  # are already terminated (and had their invoices cancelled because of that)
  # are left untouched.
  def terminate_subscription
    return if link.end_date.present?

    link.update!(end_date: period_start - 1.day, cancellation_reason: "zahl")
  end
end
