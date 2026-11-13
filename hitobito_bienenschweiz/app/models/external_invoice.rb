# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Invoice that is created and managed in Abacus. The payment state is
# pushed back by Abacus via the JSON:API (see ExternalInvoiceResource).
class ExternalInvoice < ApplicationRecord
  ERROR_CATEGORY = "rechnungen"
  STATES = %w[draft open payed cancelled error].freeze

  include I18nEnums

  belongs_to :person
  belongs_to :link, polymorphic: true, optional: true
  has_many :hitobito_log_entries, as: :subject, dependent: :nullify, inverse_of: :subject

  i18n_enum :state, STATES, scopes: true, queries: true

  validates_by_schema
  validates :state, inclusion: {in: STATES}

  scope :list, -> { order(:created_at) }

  def cancellable?
    abacus_sales_order_key.present? && !cancelled? && !error?
  end

  def to_s
    "#{model_name.human} #{id}"
  end
end
