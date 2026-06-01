# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class MemberChangeRequestService
  def initialize(member, inspector, params)
    @member = member
    @inspector = inspector
    @requested_changes = params.symbolize_keys.transform_keys { |key|
      case key
      when :firstname
        :first_name
      when :lastname
        :last_name
      else
        key
      end
    }
  end

  attr_reader :member, :inspector, :requested_changes

  def request_change
    update_email
    update_beekeeper_info

    changed_keys = requested_changes.select { |key, value|
      value.present? && member.try(key) != value
    }.keys
    only_updated_beekeeper_info = changed_keys.difference(%i[hive_count honey_yield]).empty?
    return if only_updated_beekeeper_info

    InspectionMailer.address_update_request_mail(inspector, member, requested_changes).deliver_now
  end

  def update_beekeeper_info
    return unless updated_beekeeper_info?

    member.update!({
      hive_count: new_hive_count,
      honey_yield: new_honey_yield
    }.compact)
  end

  def update_email
    return if new_email.blank?

    member.update!(email: new_email)
  end

  def new_email
    requested_changes[:email]
  end

  def new_hive_count
    requested_changes[:hive_count]
  end

  def new_honey_yield
    requested_changes[:honey_yield]
  end

  private

  def updated_beekeeper_info?
    new_hive_count.present? || new_honey_yield.present?
  end
end
