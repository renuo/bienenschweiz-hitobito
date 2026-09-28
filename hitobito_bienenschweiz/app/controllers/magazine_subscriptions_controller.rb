# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class MagazineSubscriptionsController < CrudController
  self.nesting = Group, Person

  self.permitted_attrs = [:start_date, :end_date, :subscription_type, :amount,
    :cancellation_reason]

  decorates :group, :person

  # load parents before authorization
  prepend_before_action :parent

  def create
    super(location: index_path)
  end

  def update
    super(location: index_path)
  end

  def destroy
    super(location: index_path)
  end

  private

  def build_entry
    @person.magazine_subscriptions.build(start_date: default_start_date)
  end

  def default_start_date
    Time.zone.today.beginning_of_month.next_month
  end
end
