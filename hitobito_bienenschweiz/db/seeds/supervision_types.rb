# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

seeds_path = HitobitoBienenschweiz::Wagon.root.join("spec", "fixtures")

types = YAML.load_file(seeds_path.join("supervision_types.yml"))
SupervisionType.seed(:name, *types.values.map(&:symbolize_keys))

