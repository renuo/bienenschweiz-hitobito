# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz
module Bienenschweiz::Sheet::Group
  extend ActiveSupport::Concern

  prepended do
    tabs.map! do |tab|
      next tab unless tab.path_method == :group_mailing_lists_path

      visible = lambda do |view, group|
        group.is_a?(::Group::Dachverband) && tab.options[:if].call(view, group)
      end
      Sheet::Tab.new(tab.label_key, tab.path_method, tab.options.merge(if: visible))
    end
  end
end
