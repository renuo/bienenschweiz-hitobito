# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe MemberChangeRequestService do
  subject(:service) { MemberChangeRequestService.new(person, inspector, changes) }

  let(:changes) {
    {street: "foostreet", house_no: 1, zip: 1234, location: "footown", email: "foo@bar.com"}
  }
  let(:intern_structure) { groups(:aargauer_kantonalverband) }
  let(:inspector) do
    Fabricate(:fachperson_produkte, group_id: groups(:produkte_383).id)
  end

  describe "#request_change" do
    subject(:request_change) { service.request_change }

    let!(:person) { Fabricate(:person) }

    context "when no changes are requested" do
      let(:changes) { {firstname: person.first_name, lastname: person.last_name} }

      it { expect { request_change }.not_to change { ActionMailer::Base.deliveries.count } }
      it { expect { request_change }.not_to change { person.reload } }
    end

    context "when only beekeeper information is requested" do
      let(:changes) { {hive_count: 1} }

      it { expect { request_change }.not_to change { ActionMailer::Base.deliveries.count } }
      it { expect { request_change }.to change { person.reload.hive_count } }
    end

    context "when other address changes are requested" do
      let(:changes) { {firstname: "Blubb"} }

      it { expect { request_change }.to change { ActionMailer::Base.deliveries.count }.by(1) }
    end

    context "when only a remark was left" do
      let(:changes) { {remark: "foo"} }

      it { expect { request_change }.to change { ActionMailer::Base.deliveries.count }.by(1) }
    end

    context "when beekeeper information and other address changes are requested" do
      let(:changes) { {firstname: "Blubb", hive_count: 1} }

      it { expect { request_change }.to change { ActionMailer::Base.deliveries.count }.by(1) }
      it { expect { request_change }.to change { person.reload.hive_count } }
    end
  end

  describe "#update_email" do
    subject(:update_email) do
      service.update_email
    end

    context "person with an email" do
      let!(:person) { Fabricate(:beekeeper) }

      it {
        expect { update_email }.to change { person.reload.email }.to("foo@bar.com")
      }
    end

    context "person without an email" do
      let!(:person) { Fabricate(:beekeeper, email: nil) }

      it {
        expect { update_email }.to change { person.reload.email }.from(nil).to("foo@bar.com")
      }
    end
  end

  describe "#update_beekeeper_info" do
    subject(:update_beekeeper_info) { service.update_beekeeper_info }

    let!(:person) { Fabricate(:person) }
    let(:changes) { {honey_yield: 100, hive_count: 10} }

    it "updates the beekeeper info" do
      expect { update_beekeeper_info }.to(change { person.reload.honey_yield }.to("100").and(
        change { person.reload.hive_count }.to("10")
      ))
    end
  end

  describe "#new_email" do
    subject(:new_email) { service.new_email }

    let!(:person) { Fabricate(:person) }

    it { is_expected.to eq("foo@bar.com") }
  end
end
