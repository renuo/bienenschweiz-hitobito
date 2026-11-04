# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe PeopleController, type: :request do
  let(:admin) { people(:admin) }
  let(:person) { Fabricate(:person) }
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:other_sektion) { groups(:aargauisches_seetal) }
  let(:kader) { groups(:kader_380) }
  let(:other_kader) { groups(:kader_383) }

  def add_role(group, type = Group::Kader::FachpersonBildung)
    Fabricate(:role, group:, person:, type: type.sti_name)
  end

  before do
    roles(:admin)
    sign_in(admin)
    add_role(kader)
    add_role(other_kader, Group::Kader::FachpersonZuchtVermehrung)
    add_role(groups(:vorstand_379), Group::SektionVorstand::Praesident)
  end

  describe "GET #show" do
    it "renders the Spesen Sektion toggle for groups with eligible roles only" do
      get group_person_path(kader, person)

      html = Capybara.string(response.body)
      expect(html).to have_css("a.spesen-sektion-#{kader.id}[title='Spesen Sektion']")
      expect(html).to have_css("a.spesen-sektion-#{kader.id} i.fas.fa-money-bill-1")
      expect(html).to have_css(
        "a.spesen-sektion-#{other_kader.id}[title='Spesen Sektion setzen'] i.far.fa-money-bill-1"
      )
      expect(html).not_to have_css("a.spesen-sektion-#{groups(:vorstand_379).id}")
    end
  end

  describe "PUT #spesen_sektion" do
    def put_spesen_sektion(id, **opts)
      put spesen_sektion_group_person_path(kader, person, spesen_sektion_id: id), **opts
    end

    it "sets the Spesen Sektion" do
      put_spesen_sektion(other_sektion.id)
      expect(response).to redirect_to(group_person_path(kader, person))
      expect(person.reload.spesen_sektion).to eq(other_sektion)
    end

    it "re-renders the roles via ajax" do
      put_spesen_sektion(other_sektion.id, xhr: true, as: :js)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("spesen-sektion-#{other_kader.id}")
      expect(person.reload.spesen_sektion).to eq(other_sektion)
    end

    it "does not set a Sektion without an eligible role" do
      put_spesen_sektion(groups(:baden).id, xhr: true, as: :js)
      expect(person.reload.spesen_sektion).to eq(sektion)
    end

    it "is denied for people without permission" do
      sign_in(Fabricate(:person))
      expect { put_spesen_sektion(other_sektion.id) }.to raise_error(CanCan::AccessDenied)
    end
  end
end
