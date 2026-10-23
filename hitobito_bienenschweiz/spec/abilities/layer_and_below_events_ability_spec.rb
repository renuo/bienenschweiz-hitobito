# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe "layer_and_below_events permission" do
  subject(:ability) { Ability.new(user) }

  let(:user) { Fabricate(:person) }
  let(:root) { groups(:root) }
  let(:apiservice) do
    Fabricate(:group, type: Group::Apiservice.sti_name, parent: root)
  end
  let(:kantonalverband) { groups(:aargauer_kantonalverband) }
  let(:sektion) { groups(:aarau_und_umgebung) }

  before do
    Fabricate(Group::Apiservice::VeranstaltungenKurse.sti_name.to_sym,
      group: apiservice, person: user)
  end

  [:root, :kantonalverband, :sektion].each do |layer|
    context "on the #{layer} layer" do
      let(:group) { send(layer) }
      let(:event) { Fabricate(:event, groups: [group]) }

      it "may index and export events and courses" do
        expect(ability).to be_able_to(:index_events, group)
        expect(ability).to be_able_to(:"index_event/courses", group)
        expect(ability).to be_able_to(:export_events, group)
        expect(ability).to be_able_to(:"export_event/courses", group)
      end

      it "may show and index participations" do
        expect(ability).to be_able_to(:show, event)
        expect(ability).to be_able_to(:index_participations, event)
        expect(ability).to be_able_to(:index_full_participations, event)
      end

      it "may create, update, and destroy" do
        new_event = group.events.new.tap { |e| e.groups << group }
        expect(ability).to be_able_to(:create, new_event)
        expect(ability).to be_able_to(:update, event)
        expect(ability).to be_able_to(:destroy, event)
      end

      it "may manage event participations" do
        participation = Fabricate(:event_participation, event: event)
        expect(ability).to be_able_to(:show_full, participation)
        expect(ability).to be_able_to(:update, participation)
        expect(ability).to be_able_to(:create, participation)
        expect(ability).to be_able_to(:destroy, participation)
      end

      it "may manage event roles" do
        participation = Fabricate(:event_participation, event: event)
        event_role = Fabricate(:"Event::Role::Leader", participation: participation)
        expect(ability).to be_able_to(:manage, event_role)
      end
    end
  end

  context "people and roles are not granted" do
    let(:sektion_admin_group) { groups(:sektion_admin_381) }

    it "may not update people below" do
      other = Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
        group: sektion_admin_group)
      expect(ability).not_to be_able_to(:update, other.person.reload)
    end

    it "may not manage roles below" do
      other = Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
        group: sektion_admin_group)
      expect(ability).not_to be_able_to(:destroy, other)
    end
  end
end
