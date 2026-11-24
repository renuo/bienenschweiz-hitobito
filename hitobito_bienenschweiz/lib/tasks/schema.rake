# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

wagon_schema = File.expand_path("../../db/schema.rb", __dir__)

namespace :bienenschweiz do
  # Search columns are rebuilt after every migration and depend on the configured languages.
  desc "Remove the search columns from db/schema.rb"
  task :strip_search_columns do
    lines = File.readlines(wagon_schema).grep_v(/"search_column"/)
    File.write(wagon_schema, lines.join)
  end
end

if Rake::Task.task_defined?("db:schema:dump")
  Rake::Task["db:schema:dump"].enhance do
    Rake::Task["bienenschweiz:strip_search_columns"].execute if ENV["SCHEMA"] == wagon_schema
  end
end
