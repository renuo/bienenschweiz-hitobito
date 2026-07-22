# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

# The course feedback question catalog.
# seed (instead of seed_once) keeps existing records in sync with the fixtures.

seeds_path = HitobitoBienenschweiz::Wagon.root.join("db", "seeds")

questions = YAML.load_file(seeds_path.join("feedback_questions.yml"))
FeedbackQuestion.seed(:id, *questions.map(&:symbolize_keys))
