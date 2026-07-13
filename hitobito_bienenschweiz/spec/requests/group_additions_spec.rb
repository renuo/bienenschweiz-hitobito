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

    context "with a non-layer group (Siegelimker)" do
      let(:kantonalverband) { groups(:aargauer_kantonalverband) }
      let(:sektion) { Fabricate(:sektion, parent: kantonalverband) }
      let(:siegelimker) {
        Fabricate(:group, parent: sektion, type: Group::Siegelimker.sti_name)
      }

      it "shows the roles list in the aside" do
        get group_path(siegelimker)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(Role.model_name.human(count: 2))
      end
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
        group.reload
      end
        .to not_change(Group, :count)
        .and change { group.code }.from(nil).to(2345)
    end
  end
end
