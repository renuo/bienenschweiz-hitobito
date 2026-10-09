# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Used by Abacus to push the payment state of invoices back to hitobito.
class ExternalInvoiceResource < ApplicationResource
  primary_endpoint "external_invoices", [:index, :show, :update]

  with_options writable: false, filterable: true, sortable: true do
    attribute :id, :integer_id
    attribute :person_id, :integer_id
    attribute :type, :string
    attribute :link_type, :string
    attribute :link_id, :integer_id
    attribute :period_start, :date
    attribute :issued_at, :date
    attribute :abacus_sales_order_key, :integer
  end

  with_options writable: true, filterable: true, sortable: true do
    attribute :state, :string
  end

  with_options writable: true, filterable: false, sortable: false do
    attribute :sent_at, :date
    attribute :total, :float
  end

  with_options writable: false, filterable: false, sortable: false do
    attribute :created_at, :datetime
    attribute :updated_at, :datetime
  end

  def base_scope
    ExternalInvoice.all # abilities handled by the controller
  end
end
