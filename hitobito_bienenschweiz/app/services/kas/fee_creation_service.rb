# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Kas
  class FeeCreationService
    attr_reader :qcontrol, :generated_fee

    def initialize(qcontrol)
      @qcontrol = qcontrol
      @generated_fee = {}
    end

    def perform
      response = KasClient.new.create_fee(fee_params)
      @generated_fee = {
        id: response["id"],
        total_amount: response["total_amount"],
        code: fee_type_code
      }
    rescue StandardError => e
      # Catches both KasClient::Error (API-level failures) and lower-level
      # connection failures, so a KAS outage never blocks saving a qcontrol.
      # fee_creation_state stays 'fee_not_created' and can be retried later.
      Rails.logger.error("Failed to create fee for qcontrol #{qcontrol.id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      Sentry.capture_exception(e) if defined?(Sentry)
      @generated_fee = {}
    end

    def ok?
      generated_fee[:id].present?
    end

    private

    def fee_params
      {
        person_id: qcontrol.inspector_id,
        fee_type_code: fee_type_code,
        total_amount: "0.00",
        quantity: 1,
        occurred_on: occurred_on,
        remarks: remarks,
        group_id: qcontrol.group_id,
        place: qcontrol.person.town
      }
    end

    def occurred_on
      (qcontrol.control_date || qcontrol.created_at).to_date.iso8601
    end

    def remarks
      I18n.t("fee_remarks", name: "#{qcontrol.person.last_name}, #{qcontrol.person.first_name}")
    end

    def fee_type_code
      @fee_type_code ||= if qcontrol.with_voucher?
        "young_qcontrol"
      elsif qcontrol.first_qcontrol?
        "first_qcontrol_without_qunav"
      else
        "qcontrol"
      end
    end
  end
end
