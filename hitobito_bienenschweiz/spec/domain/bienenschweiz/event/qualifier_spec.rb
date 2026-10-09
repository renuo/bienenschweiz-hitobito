# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Event::Qualifier do
  let(:kind) { Fabricate(:event_kind, grants_trial_subscription: true) }
  let(:course) { Fabricate(:course, groups: [groups(:root)], kind: kind) }
  let(:person) { Fabricate(:person) }
  let(:role_type) { :"Event::Course::Role::Participant" }
  let(:participation) do
    Fabricate(:event_participation, event: course, participant: person, active: true).tap do |p|
      Fabricate(role_type, participation: p)
    end
  end

  before do
    Fabricate(:group, type: Group::BienenZeitung.sti_name, parent: groups(:root))
  end

  def issue
    described_class.for(participation.reload).issue
  end

  it "grants a Schnupper-Abo when a participant gets qualified" do
    issue

    expect(person.magazine_subscriptions.pluck(:subscription_type))
      .to match_array(%w[schnupper_abo abo])
    expect(person.roles.where(type: Group::BienenZeitung::Abonnent.sti_name).count).to eq(1)
  end

  it "does not grant another one when re-issuing an already qualified participant" do
    issue
    person.magazine_subscriptions.destroy_all

    expect { issue }.not_to change { person.magazine_subscriptions.count }
  end

  context "without a participation" do
    it "issues qualifications without granting a trial subscription" do
      qualification_kind = Fabricate(:qualification_kind)
      Event::KindQualificationKind.create!(event_kind: kind, category: "qualification",
        role: "participant", qualification_kind: qualification_kind)
      qualifier = described_class.new(person, course, "participant")

      expect { qualifier.issue }.not_to change { person.magazine_subscriptions.count }
      expect(person.qualifications.pluck(:qualification_kind_id)).to include(qualification_kind.id)
    end
  end

  context "for a leader" do
    let(:role_type) { :"Event::Role::Leader" }

    it "grants nothing" do
      expect { issue }.not_to change { person.magazine_subscriptions.count }
    end
  end

  context "for a course kind not granting a trial subscription" do
    let(:kind) { Fabricate(:event_kind) }

    it "grants nothing" do
      expect { issue }.not_to change { person.magazine_subscriptions.count }
    end
  end
end
