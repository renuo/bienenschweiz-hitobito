# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

# The quality control catalog (dumped from the MV database).
# seed (instead of seed_once) keeps existing records in sync with the fixtures.

seeds_path = HitobitoBienenschweiz::Wagon.root.join("db", "seeds")

sections = YAML.load_file(seeds_path.join("quality_control_sections.yml"))
QualityControlSection.seed(:id, *sections.map(&:symbolize_keys))

questions = YAML.load_file(seeds_path.join("quality_control_questions.yml"))
QualityControlQuestion.seed(:id, *questions.map(&:symbolize_keys))

