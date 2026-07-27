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

    context "member_count" do
      it "shows the manually entered value for a Sektion" do
        sektion = Fabricate(:sektion, parent: groups(:aargauer_kantonalverband), member_count: 42)

        get group_path(sektion)

        expect(response.body).to include("Mitgliederanzahl")
        expect(response.body).to include("42")
      end

      it "shows the computed sum for a Kantonalverband" do
        groups(:aarau_und_umgebung).update!(member_count: 10)
        groups(:aargauisches_seetal).update!(member_count: 5)

        get group_path(groups(:aargauer_kantonalverband))

        expect(response.body).to include("Mitgliederanzahl")
        expect(response.body).to include("15")
      end

      it "does not show the field for a non-layer group" do
        get group_path(groups(:vorstand_379))

        expect(response.body).not_to include("Mitgliederanzahl")
      end
    end
  end

  describe "#edit" do
    it "shows a member_count input for a Sektion" do
      sektion = Fabricate(:sektion, parent: groups(:aargauer_kantonalverband))

      get edit_group_path(sektion)

      expect(response.body).to include('name="group[member_count]"')
    end

    it "does not show a member_count input for a Kantonalverband" do
      get edit_group_path(groups(:aargauer_kantonalverband))

      expect(response.body).not_to include('name="group[member_count]"')
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

    it "sets member_count on a Sektion" do
      sektion = Fabricate(:sektion, parent: groups(:aargauer_kantonalverband))

      expect {
        patch group_path(sektion), params: {group: {name: sektion.name, member_count: 7}}
        sektion.reload
      }.to change { sektion.member_count }.from(nil).to(7)
    end

    it "rejects member_count on a non-Sektion group" do
      patch group_path(group), params: {group: {name: group.name, member_count: 7}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("kann nur für Sektionen gesetzt werden")
    end
  end
end
