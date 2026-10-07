# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe "Event::QualificationsController", type: :request do
  let(:group) { groups(:root) }
  let(:kind) do
    Fabricate(:event_kind, grants_trial_subscription: true).tap do |kind|
      Event::KindQualificationKind.create!(event_kind: kind, category: "qualification",
        role: "participant", qualification_kind: Fabricate(:qualification_kind))
    end
  end
  let(:course) { Fabricate(:course, kind: kind, groups: [group]) }
  let(:person) { Fabricate(:person) }
  let!(:participation) do
    Fabricate(:event_participation, event: course, participant: person, active: true).tap do |p|
      Fabricate(:"Event::Course::Role::Participant", participation: p)
    end
  end

  before do
    # The qualifications list joins on these, they are only filled by the seeds.
    EventRoleTypeOrder.create!(name: Event::Course::Role::Participant.sti_name, order_weight: 1)
    Fabricate(:group, type: Group::BienenZeitung.sti_name, parent: Group::Dachverband.first)
    roles(:admin)
    sign_in(people(:admin))
  end

  def save_qualifications(*participations)
    put group_event_qualifications_path(group, course),
      params: {participation_ids: participations.map(&:id)}
  end

  it "grants a single Schnupper-Abo even when the form is saved repeatedly" do
    save_qualifications(participation)
    save_qualifications(participation)

    expect(response).to redirect_to(group_event_qualifications_path(group, course))
    expect(person.magazine_subscriptions.pluck(:subscription_type)).to eq(%w[schnupper_abo abo])
  end

  it "grants nothing to participants left unqualified" do
    save_qualifications

    expect(person.magazine_subscriptions).to be_empty
  end
end
