# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

Fabrication.configure do |config|
  config.fabricator_path = ["spec/fabricators",
    "../hitobito_bienenschweiz/spec/fabricators"]
  config.path_prefix = Rails.root
end

# Plain events require an Anlasstyp (no DB default). The core :event fabricator
# cannot be redefined, so the attribute is added to it here. Courses inherit the
# :event definition but do not use the field.
RSpec.configure do |config|
  config.before(:suite) do
    Fabrication.manager.load_definitions if Fabrication.manager.empty?
    Fabrication.manager[:event].append_or_update_attribute(:event_type, "public")
    Fabrication.manager[:course].append_or_update_attribute(:event_type, nil)
  end
end
