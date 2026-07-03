# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz
module Bienenschweiz::Sheet::Person
  extend ActiveSupport::Concern

  prepended do
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
  end
end
