# frozen_string_literal: true

#  Copyright (c) 2023, BienenSchweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require "spec_helper"

RSpec.describe RolesController, type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:role) { roles(:admin) }

  before do
    sign_in(admin)
  end

  describe "#update" do
    let!(:role) {
      Fabricate(:role, group:, type: Group::Dachverband::AdministratorBienenSchweiz.sti_name)
    }
    let(:role_params) do
      {
        export_to_website: false
      }
    end

    it "updates the person with the added fields" do
      expect do
        patch "/groups/#{group.id}/roles/#{role.id}", params: {role: role_params}
      end.not_to change { Role.count }

      role.reload
      expect(role).to be_present
      expect(role.export_to_website).to eq(false)
    end
  end
end
