# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module ExternalInvoiceRunsHelper
  # Errors of a run are logged on the invoice, or on the subscription if the
  # invoice could not even be prepared.
  def external_invoice_run_error_subscription(log_entry)
    case log_entry.subject
    when ExternalInvoice then log_entry.subject.link
    when MagazineSubscription then log_entry.subject
    end
  end

  def external_invoice_run_error_person(log_entry)
    case log_entry.subject
    when ExternalInvoice then log_entry.subject.person
    when MagazineSubscription then log_entry.subject.person
    end
  end

  # Subscriptions have no show page, link to the subscriptions tab of the person.
  def external_invoice_run_subscriptions_path(subscription)
    person = subscription.person
    group_person_magazine_subscriptions_path(person.primary_group_id || Group.root.id, person)
  end
end
