# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe RolesHelper, type: :helper do
  describe "#format_role_type_label_with_permissions" do
    Role.all_types.each do |role_type|
      it "translates all permissions of #{role_type.sti_name}" do
        expect { helper.format_role_type_label_with_permissions(role_type) }.not_to raise_error
      end
    end
  end
end
