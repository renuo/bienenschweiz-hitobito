# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Bienenschweiz::EventParticipationAbility do
  subject(:ability) { Ability.new(people(:admin)) }

  context "Group::Dachverband::AdministratorBienenSchweiz" do
    [:root, :aargauer_kantonalverband, :aarau_und_umgebung].each do |group_key|
      context "with a course in #{group_key}" do
        let(:course) do
          Fabricate(:course, groups: [groups(group_key)], kind: Fabricate(:event_kind))
        end
        let(:participant) { Fabricate(:person) }
        let(:participation) do
          Fabricate.build(:event_participation, event: course, participant: participant)
        end

        it "may add participants" do
          expect(ability).to be_able_to(:create, participation)
          expect(ability).to be_able_to(:update, participation)
        end

        it "may assign participant roles" do
          role = Event::Course::Role::Participant.new(participation: participation)
          expect(ability).to be_able_to(:create, role)
        end
      end
    end
  end
end
