# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


require "spec_helper"

RSpec.describe Api::Mobile::V1::BeekeepersController, type: :request do
  let(:fachperson_produkte) do
    Fabricate(:fachperson_produkte, group_id: groups(:produkte_383).id)
  end
  let(:beekeepers) { Fabricate.times(10, :person).sort_by { |b| [b.last_name, b.first_name] } }
  let(:honey_chairman) { Fabricate(:honey_chairman, group_id: group1.parent.id) }
  let(:group1) { groups(:aargauisches_seetal) }
  let(:group2) { groups(:aarberg) }
  let(:auth_headers) { {"Access-Token": fachperson_produkte.beeaudit_authentication_token} }

  def add_beekeeper_memberships
    beekeepers.each_with_index do |beekeeper, index|
      if index < 2
        Fabricate(:temporary_siegel_imker_role, person: beekeeper, group: group1)
      elsif index < 5
        Fabricate(:siegel_imker_role, person: beekeeper, group: group1)
      else
        Fabricate(:siegel_imker_role, person: beekeeper, group: group2)
      end
    end
  end

  context "#index" do
    before do
      add_beekeeper_memberships
      get api_mobile_v1_beekeepers_path(format: :json), headers: auth_headers
    end

    it "should contain all the siegel imkers" do
      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(5)
    end

    it "should have the right fields" do
      expected_keys = %w[id firstname lastname affix_1 affix_2 affix_3 street zip location
        kanton birthdate house_no hive_count honey_yield telephone mobile email]
      expect(json_response.first.keys).to match_array(expected_keys)
    end

    it "set the right data" do
      expected_json = beekeepers.first.as_mobile_json.stringify_keys
      expected_json["birthdate"] = beekeepers.first&.birthday&.to_fs(:db)
      json_response.first.each_key do |key|
        expect(json_response.first[key]).to eq(expected_json[key])
      end
    end

    it "should only include that beekeepers that can be inspected by current fachperson_produkte" do
      expect(json_response.pluck("id")).to eq(beekeepers[0..4].pluck(:id))
    end

    it "should only include the beekeepers with role siegel_imker (not the honey chairman)" do
      expect(json_response.pluck("id")).to_not include(honey_chairman.id)
    end

    context "when a either first_name or last_name are nil" do
      let(:beekeepers) do
        [
          Fabricate(:person, first_name: nil, last_name: "Bar"),
          Fabricate(:person, first_name: "Foo", last_name: nil),
          Fabricate(:person, first_name: nil, last_name: nil)
        ]
      end

      it "should map nil fields to empty strings" do
        expect(json_response).to include(
          a_hash_including("firstname" => "", "lastname" => "Bar"),
          a_hash_including("firstname" => "Foo", "lastname" => ""),
          a_hash_including("firstname" => "", "lastname" => "Unbekannt (#{beekeepers.last.id})")
        )
      end
    end
  end

  context "#update" do
    let(:changes) do
      {firstname: "foo", lastname: "bar", street: "foo&bar street", house_no: 1, zip: 1234,
       location: "footown", telephone: "0123456789", mobile: "0123456789",
       email: "foo@bar.com", remark: "Foo Bar."}
    end
    let(:mail) {
      InspectionMailer.address_update_request_mail(fachperson_produkte, beekeepers.first, changes)
    }
    let(:beekeeper) { beekeepers.first }

    subject do
      add_beekeeper_memberships
      post api_mobile_v1_beekeeper_update_path(beekeeper), params: {member: changes},
        headers: auth_headers
    end

    it "responds with success" do
      subject
      expect(response).to have_http_status(:no_content)
    end
    it { expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1) }
    it { expect { subject }.to change { beekeeper.reload.email }.to(changes[:email]) }
    it {
      expect(mail.subject)
        .to eq("Antrag für eine Adressänderung von Siegelimker #{beekeeper.full_name}")
    }
    it { expect(mail.to).to eq([InspectionMailer::APP_NOTIFICATIONS_EMAIL]) }
    it { expect(mail.body.encoded).to match changes[:remark] }

    it "renders the old values" do
      beekeeper.as_json(only: %i[first_name last_name street house_no zip location],
        methods: %i[telephone email]).each_value do |field|
        expect(mail.body.encoded).to match(CGI.escapeHTML(field)) if field
      end
    end

    it "renders the proposed changes" do
      changes.each_value do |value|
        expect(mail.body.encoded).to match(CGI.escapeHTML(value.to_s))
      end
    end

    context "when beekeeper is not inspectable by the fachperson_produkte" do
      let(:group) { groups(:aarberg) }
      let(:beekeeper) { Fabricate(:beekeeper, group_id: group.id) }

      it "is not permitted" do
        expect { subject }.not_to(change { ActionMailer::Base.deliveries.count })
        expect(response).to have_http_status :not_found
      end
    end
  end
end
