# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

module Bienenschweiz::Group
  extend ActiveSupport::Concern

  MAX_CODE_DIGITS = 6

  included do
    # Define additional used attributes
    # self.used_attributes += [:website, :bank_account, :description]
    # self.superior_attributes = [:bank_account]

    root_types Group::Dachverband

    validates :code,
      numericality: {only_integer: true, greater_than: 0,
                     less_than: 10**MAX_CODE_DIGITS},
      uniqueness: true,
      allow_nil: true

    validates :member_count,
      numericality: {only_integer: true, greater_than_or_equal_to: 0},
      allow_nil: true
    validate :assert_member_count_only_on_sektion

    alias_method_chain :to_s, :code
    alias_method_chain :display_name, :code

    def self.order_by_type
      joins("INNER JOIN group_type_orders ON group_type_orders.name = groups.type")
        .reorder("group_type_orders.order_weight ASC, groups.code ASC, groups.name ASC")
    end

    def canton_short
      canton&.upcase
    end
  end

  def to_s_with_code(_format = :default)
    [code, name].compact.join(" ")
  end

  def display_name_with_code
    [code, display_name_without_code].compact.join(" ")
  end

  def sorting_name
    code&.to_s&.rjust(MAX_CODE_DIGITS, "0") || display_name
  end

  # Sektion holds the manually entered count; other layers show the sum of their
  # descendant Sektionen's counts; non-layer groups have no meaningful count at all.
  def member_count
    if is_a?(Group::Sektion)
      self[:member_count]
    elsif layer?
      descendants.where(type: Group::Sektion.sti_name).sum(:member_count)
    end
  end

  private

  def assert_member_count_only_on_sektion
    return if is_a?(Group::Sektion)

    errors.add(:member_count, :only_for_sektion) if self[:member_count].present?
  end
end
