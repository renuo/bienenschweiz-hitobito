# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module SupervisionsHelper
  # Options for all results of all kinds, tagged with their kind and hidden
  # unless they belong to the currently selected kind. Switching the kind
  # toggles the visible options (see app/assets/javascripts/wagon.js.coffee).
  def supervision_result_options(supervision)
    current_kind = supervision.kind.presence || Supervision::KINDS.keys.first.to_s
    Supervision::KINDS.flat_map do |kind, results|
      results.map do |result|
        [Supervision.result_labels[result.to_sym], result,
          {data: {kind: kind}, hidden: kind.to_s != current_kind}]
      end
    end
  end
end
