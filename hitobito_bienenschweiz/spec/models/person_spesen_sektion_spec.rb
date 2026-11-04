# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Person, "spesen sektion" do
  let(:person) { Fabricate(:person) }
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:other_sektion) { groups(:aargauisches_seetal) }

  def add_role(group, type = Group::Kader::FachpersonBildung, **attrs)
    Fabricate(:role, group:, person:, type: type.sti_name, **attrs)
  end

  it "is not set without an eligible role" do
    add_role(groups(:vorstand_379), Group::SektionVorstand::Praesident)
    expect(person.reload.spesen_sektion).to be_nil
  end

  Bienenschweiz::Person::SPESEN_ROLES.each do |type|
    it "defaults to the Sektion of the first #{type.demodulize} role" do
      add_role(groups(:kader_380), type.constantize)
      add_role(groups(:kader_383), type.constantize)
      expect(person.reload.spesen_sektion).to eq(sektion)
    end
  end

  it "keeps an explicitly chosen Sektion when roles change" do
    add_role(groups(:kader_380))
    add_role(groups(:kader_383))
    person.reload.update!(spesen_sektion_id: other_sektion.id)

    add_role(groups(:kader_380), Group::Kader::FachpersonProdukte)
    expect(person.reload.spesen_sektion).to eq(other_sektion)
  end

  it "switches to the remaining eligible Sektion when the chosen role is removed" do
    add_role(groups(:kader_380))
    role = add_role(groups(:kader_383))
    person.reload.update!(spesen_sektion_id: other_sektion.id)

    role.destroy!
    expect(person.reload.spesen_sektion).to eq(sektion)
  end

  it "is un-set when the only eligible role is ended" do
    role = add_role(groups(:kader_380), start_on: 1.month.ago)
    expect(person.reload.spesen_sektion).to eq(sektion)

    role.update!(end_on: Date.yesterday)
    expect(person.reload.spesen_sektion).to be_nil
  end

  it "is un-set when the only eligible role is destroyed" do
    role = add_role(groups(:kader_380))
    role.really_destroy!
    expect(person.reload.spesen_sektion).to be_nil
  end

  it "cannot be set to a Sektion without an eligible role" do
    add_role(groups(:kader_380))
    person.reload.spesen_sektion_id = other_sektion.id
    expect(person).not_to be_valid
    expect(person.errors[:spesen_sektion_id]).to be_present
  end
end
