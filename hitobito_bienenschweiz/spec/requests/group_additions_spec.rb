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

  describe "group tabs" do
    [:root, :aargauer_kantonalverband, :aarau_und_umgebung, :vorstand_379].each do |group_key|
      it "shows only the applicable tabs for #{group_key}" do
        group = groups(group_key)
        get group_path(group)

        nav = Capybara.string(response.body).find(".nav-sub")
        expect(nav).to have_no_link(href: group_person_add_requests_path(group))
        expect(nav).to have_no_link("Statistiken")

        abos_path = group_mailing_lists_path(group, returning: true)
        if group_key == :root
          expect(nav).to have_link("Abos", href: abos_path)
        else
          expect(nav).to have_no_link(href: abos_path)
        end
      end
    end
  end

  describe "person add request settings" do
    it "denies access to the request queue" do
      expect { get group_person_add_requests_path(root_group) }.to raise_error(CanCan::AccessDenied)
    end

    it "prevents admins from activating manual approval" do
      expect do
        post group_person_add_requests_path(root_group)
      end.to raise_error(CanCan::AccessDenied)
      expect(root_group.reload.require_person_add_requests?).to be(false)
    end
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

    it "shows enabled name and code inputs for an admin" do
      get edit_group_path(groups(:aarau_und_umgebung))

      html = Capybara.string(response.body)
      expect(html).to have_field("group[name]", disabled: false)
      expect(html).to have_field("group[code]", disabled: false)
    end
  end

  context "as a Sektion admin" do
    let(:sektion) { groups(:aarau_und_umgebung) }
    let(:sektion_admin) { Fabricate(:person) }

    before do
      Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
        group: groups(:sektion_admin_381), person: sektion_admin)
      sektion.update!(code: 381)
      sign_in(sektion_admin)
    end

    it "shows disabled name and code inputs" do
      get edit_group_path(sektion)

      html = Capybara.string(response.body)
      expect(html).to have_field("group[name]", disabled: true)
      expect(html).to have_field("group[code]", disabled: true)
    end

    it "ignores name and code on update but saves other attributes" do
      expect {
        patch group_path(sektion), params: {group: {name: "Hacked", code: 999, member_count: 3}}
        sektion.reload
      }.to not_change { sektion.name }
        .and not_change { sektion.code }
        .and change { sektion.member_count }.to(3)
    end

    it "may not create a group" do
      expect {
        post groups_path, params: {group: {parent_id: sektion.id,
                                           type: Group::SektionVorstand.sti_name,
                                           name: "Neuer Vorstand"}}
      }.to raise_error(CanCan::AccessDenied)
    end

    it "may not destroy a group" do
      group = Fabricate(Group::SektionVorstand.sti_name, parent: sektion)

      expect { delete group_path(group) }.to raise_error(CanCan::AccessDenied)
      expect(group.reload.deleted_at).to be_nil
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
