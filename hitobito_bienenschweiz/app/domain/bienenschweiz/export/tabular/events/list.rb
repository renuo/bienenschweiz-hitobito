# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Adds the wagon-specific event attributes to the core event CSV/XLSX export.
module Bienenschweiz::Export::Tabular::Events::List
  private

  def add_additional_labels(labels)
    super
    add_used_attribute_label(labels, :show_in_bienenzeitung)
  end
end
