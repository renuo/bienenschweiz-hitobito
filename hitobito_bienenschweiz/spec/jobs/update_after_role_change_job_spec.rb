# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe People::UpdateAfterRoleChangeJob do
  let(:person) { Fabricate(:person) }
  let(:sektion) { groups(:aarau_und_umgebung) }

  # The core job excludes the root person, which is not part of the wagon fixtures.
  before { allow(Person).to receive(:root).and_return(people(:admin)) }

  def add_role(group, **attrs)
    Fabricate(:role, group:, person:, type: Group::Kader::FachpersonBildung.sti_name, **attrs)
  end

  it "un-sets the Spesen Sektion once the only eligible role has expired" do
    add_role(groups(:kader_380), start_on: 1.month.ago, end_on: 1.day.from_now)
    expect(person.reload.spesen_sektion).to eq(sektion)

    travel_to(2.days.from_now) { described_class.new.perform }
    expect(person.reload.spesen_sektion).to be_nil
  end

  it "sets the Spesen Sektion once an eligible role has started" do
    add_role(groups(:kader_380), start_on: 1.day.from_now)
    expect(person.reload.spesen_sektion).to be_nil

    travel_to(2.days.from_now) { described_class.new.perform }
    expect(person.reload.spesen_sektion).to eq(sektion)
  end
end
