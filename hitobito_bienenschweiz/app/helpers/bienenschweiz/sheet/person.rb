# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz
module Bienenschweiz::Sheet::Person
  extend ActiveSupport::Concern

  prepended do # rubocop:disable Metrics/BlockLength
    # The Info tab (group_person_path) has no no_alt: true, so its substring regex matches any
    # nested path (e.g. memos/new) and it wins first in detect. Mark it exact-match-only so
    # the actual nested-resource tab gets highlighted on new/edit/show actions.
    tabs.map! do |tab|
      next tab unless tab.path_method == :group_person_path

      Sheet::Tab.new(tab.label_key, tab.path_method, tab.options.merge(no_alt: true))
    end

    tabs << Sheet::Tab.new(
      "people.tabs.bienenschweiz_qcontrols",
      :group_person_qcontrols_path,
      if: ->(view, _group, _person) { view.can?(:index, Qcontrol) }
    )
    tabs << Sheet::Tab.new(
      "people.tabs.bienenschweiz_supervisions",
      :group_person_supervisions_path,
      if: ->(view, _group, _person) { view.can?(:index, Supervision) }
    )
    tabs << Sheet::Tab.new(
      "people.tabs.bienenschweiz_memos",
      :group_person_memos_path,
      if: ->(view, _group, _person) { view.can?(:index, Memo) }
    )
    tabs << Sheet::Tab.new(
      "people.tabs.bienenschweiz_magazine_subscriptions",
      :group_person_magazine_subscriptions_path,
      if: ->(view, _group, _person) { view.can?(:index, MagazineSubscription) }
    )
    tabs << Sheet::Tab.new(
      "people.tabs.bienenschweiz_siegelimker_profile",
      :group_person_siegelimker_profile_path,
      if: lambda { |view, _group, person|
        person.siegelimker? &&
          view.can?(:show, person.siegelimker_profile || SiegelimkerProfile.new(person:))
      }
    )
  end
end
