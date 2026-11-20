# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class ExternalInvoiceRunsController < CrudController
  helper_method :run_errors

  private

  def list_entries
    super.list.page(params[:page])
  end

  def run_errors
    @run_errors ||= entry.hitobito_log_entries.includes(:subject).order(:created_at)
  end
end
