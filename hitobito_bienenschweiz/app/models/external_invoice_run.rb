# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# One execution of an invoicing job that created invoices in Abacus (a "Rechnungslauf").
# Errors of the run are stored as HitobitoLogEntry referencing it.
class ExternalInvoiceRun < ApplicationRecord
  STATES = %w[running finished failed].freeze

  include I18nEnums

  has_many :hitobito_log_entries, dependent: :nullify

  i18n_enum :state, STATES, queries: true

  validates_by_schema
  validates :state, inclusion: {in: STATES}

  scope :list, -> { order(started_at: :desc) }

  def finish!(state, created_count:)
    update!(state: state, created_count: created_count, error_count: hitobito_log_entries.count,
      finished_at: Time.current)
  end

  def to_s
    "#{model_name.human} #{I18n.l(started_at, format: :long)}"
  end
end
