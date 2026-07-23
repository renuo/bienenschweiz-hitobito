# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe RolesController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:sektion_admin_group) { groups(:sektion_admin_381) }
  let(:siegelimker_group) { Fabricate(:group, type: Group::Siegelimker.sti_name, parent: sektion) }

  let(:target_person) { Fabricate(:person) }
  let!(:beekeeper_role) do
    Fabricate(Group::Siegelimker::Siegelimker.sti_name.to_sym,
      group: siegelimker_group, person: target_person)
  end

  let(:new_role_params) do
    {group_id: siegelimker_group.id, type: Group::Siegelimker::Siegelimker.sti_name,
     person_id: Fabricate(:person).id}
  end

  shared_examples "may manage beekeeper roles" do
    it "GET new renders the form" do
      get new_group_role_path(siegelimker_group),
        params: {role: {group_id: siegelimker_group.id,
                        type: Group::Siegelimker::Siegelimker.sti_name}}
      expect(response).to have_http_status(:ok)
    end

    it "GET edit renders the form" do
      get edit_group_role_path(siegelimker_group, beekeeper_role)
      expect(response).to have_http_status(:ok)
    end

    it "POST create creates a new beekeeper role" do
      expect do
        post group_roles_path(siegelimker_group), params: {role: new_role_params}
      end.to change { Role.count }.by(1)
    end

    it "PATCH update updates the beekeeper role" do
      patch group_role_path(siegelimker_group, beekeeper_role),
        params: {role: {start_on: 1.day.ago.to_date}}

      expect(beekeeper_role.reload.start_on).to eq(1.day.ago.to_date)
    end

    it "DELETE destroy destroys the beekeeper role" do
      expect do
        delete group_role_path(siegelimker_group, beekeeper_role)
      end.to change { Role.count }.by(-1)
    end
  end

  shared_examples "may not manage beekeeper roles" do
    it "GET new raises access denied" do
      expect do
        get new_group_role_path(siegelimker_group),
          params: {role: {group_id: siegelimker_group.id,
                          type: Group::Siegelimker::Siegelimker.sti_name}}
      end.to raise_error(CanCan::AccessDenied)
    end

    it "GET edit raises access denied" do
      expect do
        get edit_group_role_path(siegelimker_group, beekeeper_role)
      end.to raise_error(CanCan::AccessDenied)
    end

    it "POST create raises access denied" do
      expect do
        post group_roles_path(siegelimker_group), params: {role: new_role_params}
      end.to raise_error(CanCan::AccessDenied)
    end

    it "PATCH update raises access denied" do
      expect do
        patch group_role_path(siegelimker_group, beekeeper_role),
          params: {role: {start_on: 1.day.ago.to_date}}
      end.to raise_error(CanCan::AccessDenied)
    end

    it "DELETE destroy raises access denied" do
      expect do
        delete group_role_path(siegelimker_group, beekeeper_role)
      end.to raise_error(CanCan::AccessDenied)
    end
  end

  context "as Group::Dachverband::AdministratorBienenSchweiz" do
    before do
      admin = Fabricate(Group::Dachverband::AdministratorBienenSchweiz.sti_name.to_sym,
        group: groups(:root)).person
      sign_in(admin)
    end

    include_examples "may manage beekeeper roles"
  end

  context "as Group::SektionAdministrator::AdminSektion" do
    before do
      user = Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
        group: sektion_admin_group).person
      sign_in(user)
    end

    include_examples "may not manage beekeeper roles"
  end

  context "as Group::SektionAdministrator::Kontakte" do
    before do
      user = Fabricate(Group::SektionAdministrator::Kontakte.sti_name.to_sym,
        group: sektion_admin_group).person
      sign_in(user)
    end

    include_examples "may not manage beekeeper roles"
  end
end
