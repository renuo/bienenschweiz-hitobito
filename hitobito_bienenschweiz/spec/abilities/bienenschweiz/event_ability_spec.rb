# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Bienenschweiz::EventAbility do
  subject(:ability) { Ability.new(user) }

  let(:sektion) { groups(:aarau_und_umgebung) }

  context "Group::Dachverband::AdministratorBienenSchweiz" do
    let(:user) { people(:admin) }

    {Event => :event, Event::Course => :course}.each do |event_type, fabricator|
      context "with #{event_type.name}" do
        [:aargauer_kantonalverband, :aarau_und_umgebung].each do |group_key|
          context "in #{group_key}" do
            let(:group) { groups(group_key) }
            let(:event) do
              attrs = {groups: [group]}
              attrs[:kind] = Fabricate(:event_kind) if event_type == Event::Course
              Fabricate(fabricator, attrs)
            end

            it "may create, update and destroy" do
              new_event = event_type.new.tap { |e| e.groups << group }
              expect(ability).to be_able_to(:new, new_event)
              expect(ability).to be_able_to(:create, new_event)
              expect(ability).to be_able_to(:update, event)
              expect(ability).to be_able_to(:destroy, event)
            end

            it "may not qualify" do
              expect(ability).not_to be_able_to(:qualify, event)
            end
          end
        end
      end
    end

    it "may not create events in archived groups" do
      sektion.update_column(:archived_at, 1.day.ago)
      new_event = Event.new.tap { |e| e.groups << sektion }
      expect(ability).not_to be_able_to(:create, new_event)
    end
  end

  context "Group::SektionAdministrator::AdminSektion" do
    let(:user) { Fabricate(:person) }
    let(:other_sektion) { groups(:aargauisches_seetal) }

    before do
      Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
        group: groups(:sektion_admin_381), person: user)
    end

    it "may not create or destroy events in another sektion" do
      new_event = Event.new.tap { |e| e.groups << other_sektion }
      expect(ability).not_to be_able_to(:create, new_event)
      expect(ability).not_to be_able_to(:destroy, Fabricate(:event, groups: [other_sektion]))
    end
  end
end
