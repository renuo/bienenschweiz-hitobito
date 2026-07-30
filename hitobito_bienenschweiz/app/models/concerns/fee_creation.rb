# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module FeeCreation
  extend ActiveSupport::Concern

  included do
    enum :fee_creation_state, {fee_not_required: "fee_not_required",
                               fee_not_created: "fee_not_created",
                               fee_ok: "fee_ok"}

    after_commit :create_fee, if: :should_create_fee?, on: %i[create update]
  end

  def should_create_fee?
    person.present? && # beekeeper is set
      inspector.present? && # inspector is present on kas
      fee_not_created? && # fee has not already been created
      group.is_a?(Group::Sektion) && # we are in a section
      control_performed? # control has been performed
  end

  def create_fee
    service = Kas::FeeCreationService.new(self)
    service.perform
    # Don't use 'update' here. see related Rails issue: https://github.com/rails/rails/issues/14493
    return unless service.ok?

    # rubocop:disable Rails/SkipsModelValidations
    update_columns(fee_creation_state: "fee_ok",
      fee_id: service.generated_fee[:id],
      fee_total_amount: service.generated_fee[:total_amount],
      fee_type_code: service.generated_fee[:code])
    # rubocop:enable Rails/SkipsModelValidations
  end
end
