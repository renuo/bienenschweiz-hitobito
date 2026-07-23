# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe FeedbackRoundAbility do
  subject(:ability) { Ability.new(user) }

  let(:event) { Fabricate(:course, kind: Fabricate(:event_kind)) }
  let(:round) { Fabricate.build(:feedback_round, event:) }
  let(:user) { Fabricate(:person) }

  context "as the course leader" do
    before do
      participation = Fabricate(:event_participation, event:, active: true, participant: user)
      Fabricate(Event::Role::Leader.sti_name.to_sym, participation:)
    end

    it "may start, read, and report on feedback rounds" do
      expect(ability).to be_able_to(:create, round)
      expect(ability).to be_able_to(:read, round)
      expect(ability).to be_able_to(:report, round)
    end

    it "may not access the cross-course aggregate report" do
      expect(ability).not_to be_able_to(:index_report, FeedbackRound)
    end
  end

  context "as an unrelated person" do
    it "may not start feedback rounds" do
      expect(ability).not_to be_able_to(:create, round)
      expect(ability).not_to be_able_to(:read, round)
      expect(ability).not_to be_able_to(:report, round)
    end
  end

  context "as the org-wide administrator" do
    before do
      Fabricate(Group::Dachverband::AdministratorBienenSchweiz.sti_name.to_sym,
        group: Group.root, person: user)
    end

    it "may access the cross-course aggregate report" do
      expect(ability).to be_able_to(:index_report, FeedbackRound)
    end
  end
end
