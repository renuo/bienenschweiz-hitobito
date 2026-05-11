# frozen_string_literal: true

#  Copyright (c) 2023, BienenSchweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require "spec_helper"

RSpec.describe GroupsController, type: :request do
  let(:root_group) { groups(:root) }
  let(:admin) { people(:admin) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#show" do
    let(:group) {
      Fabricate(:group, parent: root_group, code: 1234, type: Group::Kantonalverband.sti_name)
    }

    it "shows the added fields" do
      get group_path(group)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(group.code.to_s)
    end
  end

  describe "#update" do
    let!(:group) { Fabricate(:group, parent: root_group, type: Group::Kantonalverband.sti_name) }
    let(:group_params) do
      {
        name: "Some Group",
        code: 2345
      }
    end

    it "updates the group with the added fields" do
      expect do
        patch group_path(group), params: {group: group_params}
      end.not_to change { Group.count }

      group.reload
      expect(group).to be_present
      expect(group.code).to eq(2345)
    end
  end
end
