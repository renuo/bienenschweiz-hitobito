# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class MagazineSubscriptionReportsController < ApplicationController
  before_action :authorize_action

  def index
    @report = MagazineSubscriptions::Report.new
  end

  # One row per subscriber with their postal address, for the Bienenzeitung mailing.
  def export
    csv = Export::Tabular::MagazineSubscriptions::List.csv(ability: current_ability)

    send_data csv, type: :csv, disposition: "attachment", filename: export_filename
  end

  private

  def authorize_action
    authorize!(:index_report, MagazineSubscription)
  end

  def export_filename
    "bienen-abos_#{Time.zone.today.strftime("%Y-%m-%d")}.csv"
  end
end
