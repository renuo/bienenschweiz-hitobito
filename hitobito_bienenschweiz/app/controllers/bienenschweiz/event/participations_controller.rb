# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz::Event::ParticipationsController
  extend ActiveSupport::Concern

  prepended do
    instructor_fee_actions = %i[new_kas_instructor_fees create_kas_instructor_fees]
    skip_authorize_resource only: %i[create_kas_fees] + instructor_fee_actions
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
  def create_kas_fees
    authorize!(:update, @event)

    unless @event.kas_fees_creatable?
      return redirect_to group_event_participations_path(@group, @event),
        alert: t("event/participations.create_kas_fees.not_creatable")
    end

    failed_names = []
    client = KasClient.new
    eligible_participants.each do |participation|
      client.create_fee(kas_fee_params(participation))
    rescue KasClient::Error => e
      failed_names << "#{participation.person}: #{e.message}"
    end

    @event.update_column(:kas_fees_created, true) if failed_names.size < eligible_participants.size

    flash_key = failed_names.empty? ? :notice : :alert
    if failed_names.any?
      flash[:warning] = t("event/participations.create_kas_fees.failed_names",
        names: failed_names.join(", "))
    end
    redirect_to group_event_participations_path(@group, @event),
      flash_key => kas_fees_flash(eligible_participants.size, failed_names.size)
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity

  def new_kas_instructor_fees
    authorize!(:update, @event)
    unless @event.kas_instructor_fees_creatable?
      return redirect_to group_event_participations_path(@group, @event),
        alert: t("event/participations.kas_instructor_fees.not_creatable")
    end
    @instructor_participations = instructor_participations
    @years = event_years
    @participant_count = participant_count
    @per_year_budget = per_year_budget(@participant_count)
  end

  def create_kas_instructor_fees
    authorize!(:update, @event)
    unless @event.kas_instructor_fees_creatable?
      return redirect_to group_event_participations_path(@group, @event),
        alert: t("event/participations.kas_instructor_fees.not_creatable")
    end
    failed, attempted = build_instructor_fees
    mark_instructor_fees_created if attempted > failed.size
    if failed.any?
      redirect_to group_event_participations_path(@group, @event),
        alert: t("event/participations.kas_instructor_fees.failed_names",
          names: failed.join(", "))
    else
      redirect_to group_event_participations_path(@group, @event),
        notice: t("event/participations.kas_instructor_fees.success")
    end
  end

  private

  def build_instructor_fees
    client = KasClient.new
    failed = []
    attempted = 0
    params[:fees]&.each do |person_id, years|
      years.each do |year, amount|
        next if amount.blank? || amount.to_f.zero?
        attempted += 1
        create_instructor_fee(client, person_id, year, amount, failed)
      end
    end
    [failed, attempted]
  end

  def mark_instructor_fees_created
    year = Time.zone.today.year
    updated = (@event.kas_instructor_fees_created_years + [year]).uniq
    @event.update_column(:kas_instructor_fees_created_years, updated)
  end

  def create_instructor_fee(client, person_id, year, amount, failed)
    client.create_fee(kas_instructor_fee_params(person_id.to_i, amount.to_f))
  rescue KasClient::Error => e
    failed << "#{Person.find_by(id: person_id)} (#{year}): #{e.message}"
  end

  def participant_count
    @event.participations.active.joins(:roles)
      .where(event_roles: {type: @event.participant_types.map(&:sti_name)})
      .distinct.count
  end

  def per_year_budget(count)
    case count
    when 6..12 then 275
    when 13..23 then 475
    when 24.. then 750
    else 0
    end
  end

  def instructor_participations
    @event.participations.active.joins(:roles)
      .where(event_roles: {type: instructor_role_types})
      .includes(:participant)
      .preload(:roles)
      .distinct
  end

  def instructor_role_types
    [Event::Role::Leader, Event::Role::AssistantLeader].map(&:sti_name)
  end

  def event_years
    start_at = @event.dates.minimum(:start_at)
    return [Time.zone.today.year] unless start_at

    min = start_at.year
    min += 1 if start_at.month > 6
    max = max_event_year(start_at)
    return [] if min > max

    (min..max).to_a
  end

  def max_event_year(start_at)
    @event.dates.map { |d| (d.finish_at || d.start_at).year }.max || start_at.year
  end

  def kas_instructor_fee_params(person_id, amount)
    {
      person_id: person_id,
      fee_type_code: @event.kind.kas_fee_code,
      occurred_on: Time.zone.today.iso8601,
      quantity: 1,
      total_amount: format("%.2f", amount),
      group_id: @group.id
    }
  end

  def eligible_participants
    @eligible_participants ||= kas_participants.select { |p| precondition_met?(p) }
  end

  def kas_participants
    @kas_participants ||= @event.participations.active.joins(:roles)
      .where(event_roles: {type: @event.participant_types.map(&:sti_name)})
      .includes(:participant)
  end

  def precondition_met?(participation)
    # :nocov:
    return true unless @event.supports_applications && @event.course_kind?
    # :nocov:

    Event::PreconditionChecker.new(@event, participation.person).valid?
  end

  def kas_fee_params(participation)
    {
      person_id: participation.participant_id,
      fee_type_code: @event.kind.kas_fee_code,
      occurred_on: @event.dates.minimum(:start_at)&.to_date&.iso8601 ||
        Time.zone.today.iso8601,
      total_amount: "0.00",
      quantity: 1,
      group_id: kas_fee_group_id(participation)
    }
  end

  # KAS requires group_id to reference a Sektion. The event's own group may be nested
  # under a Kantonalverband or the Dachverband, so fall back to the participant's primary
  # group in that case, letting them resolve the issue by fixing their primary group.
  # Only a layer group (e.g. a Sektion) can be used, so a primary group in a sub group
  # like Kader is resolved up to its layer group.
  def kas_fee_group_id(participation)
    return @group.id if @group.is_a?(Group::Sektion)

    participation.person.layer_group&.id
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
