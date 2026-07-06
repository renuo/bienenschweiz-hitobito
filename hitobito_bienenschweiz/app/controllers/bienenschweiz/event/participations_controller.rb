# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz::Event::ParticipationsController
  extend ActiveSupport::Concern

  prepended do
    skip_authorize_resource only: [:create_kas_fees]
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
  def create_kas_fees
    authorize!(:update, @event)

    failed_names = []
    client = KasClient.new
    eligible_participants.each do |participation|
      client.create_fee(kas_fee_params(participation))
    rescue KasClient::Error
      failed_names << participation.person.to_s
    end

    flash_key = failed_names.empty? ? :notice : :alert
    if failed_names.any?
      flash[:warning] = t("event/participations.create_kas_fees.failed_names",
        names: failed_names.join(", "))
    end
    redirect_to group_event_participations_path(@group, @event),
      flash_key => kas_fees_flash(eligible_participants.size, failed_names.size)
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity

  private

  def eligible_participants
    @eligible_participants ||= kas_participants.select { |p| precondition_met?(p) }
  end

  def kas_participants
    @kas_participants ||= @event.participations.joins(:roles)
      .where(event_roles: {type: @event.participant_types.map(&:sti_name)})
      .includes(:participant)
  end

  def precondition_met?(participation)
    return true unless @event.supports_applications && @event.course_kind?

    Event::PreconditionChecker.new(@event, participation.person).valid?
  end

  def kas_fee_params(participation)
    {
      person_id: participation.participant_id,
      fee_type_code: @event.kind&.kas_fee_code,
      occurred_on: @event.dates.minimum(:start_at)&.to_date&.iso8601 ||
        Time.zone.today.iso8601,
      total_amount: "0.00",
      quantity: 1,
      group_id: @group.id
    }
  end

  def kas_fees_flash(total, failure_count)
    if failure_count.zero?
      t("event/participations.create_kas_fees.success", count: total)
    else
      t("event/participations.create_kas_fees.partial_failure",
        success: total - failure_count,
        total: total)
    end
  end
end
