# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Kas::FeeCreationService do
  let(:base_url) { "https://kas.example.com" }
  let(:group) { Fabricate(:sektion) }
  let(:kader_group) { Fabricate(:group, parent: group, type: Group::Kader.sti_name) }
  let(:inspector) { Fabricate(:fachperson_produkte, group_id: kader_group.id) }
  let(:person) { Fabricate(:person, first_name: "Maja", last_name: "Biene", town: "Bern") }

  # fee_creation_state starts at 'fee_ok' so fabricating the qcontrol does not itself
  # trigger Qcontrol's own FeeCreation after_commit callback (which would otherwise make
  # an extra, untested KAS call); it is reset to the real default right before use, since
  # this spec exercises Kas::FeeCreationService in isolation from that callback.
  let(:qcontrol) do
    Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
      control_date: Date.new(2026, 5, 1), with_voucher: false,
      fee_creation_state: "fee_ok").tap { |q|
      q.update_column(:fee_creation_state,
        "fee_not_created")
    }
  end

  subject(:service) { described_class.new(qcontrol) }

  before do
    allow(Settings.kas).to receive(:base_url).and_return(base_url)
    allow(Settings.kas).to receive(:api_token).and_return("test-token")
  end

  describe "#perform" do
    context "when the KAS API succeeds" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees")
          .to_return(status: 201, body: {id: 42, total_amount: "20.00"}.to_json,
            headers: {"Content-Type" => "application/json"})
      end

      it "is ok?" do
        service.perform
        expect(service).to be_ok
      end

      it "stores the generated fee's id, total_amount and code" do
        service.perform
        expect(service.generated_fee).to eq(
          id: 42, total_amount: "20.00", code: "first_qcontrol_without_qunav"
        )
      end

      it "sends the inspector as person_id" do
        service.perform
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req| JSON.parse(req.body)["fee"]["person_id"] == inspector.id }
      end

      it "sends the qcontrol's group_id" do
        service.perform
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req| JSON.parse(req.body)["fee"]["group_id"] == group.id }
      end

      it "sends the control_date as occurred_on" do
        service.perform
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req| JSON.parse(req.body)["fee"]["occurred_on"] == "2026-05-01" }
      end

      it "falls back to created_at when control_date is blank" do
        qcontrol.update_column(:control_date, nil)
        travel_to(Date.new(2026, 6, 15)) do
          qcontrol.update_column(:created_at, Time.zone.now)
          service.perform
        end
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req| JSON.parse(req.body)["fee"]["occurred_on"] == "2026-06-15" }
      end

      it "sends remarks with the beekeeper's name" do
        service.perform
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req| JSON.parse(req.body)["fee"]["remarks"] == "Betriebsprüfung Biene, Maja" }
      end

      it "sends the beekeeper's town as place" do
        service.perform
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req| JSON.parse(req.body)["fee"]["place"] == "Bern" }
      end

      it "sends a placeholder total_amount of 0.00 and quantity 1" do
        service.perform
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req|
            body = JSON.parse(req.body)["fee"]
            body["total_amount"] == "0.00" && body["quantity"] == 1
          }
      end

      it "does not send a state, leaving the KAS default of accepted" do
        service.perform
        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
          .with { |req| !JSON.parse(req.body)["fee"].key?("state") }
      end

      context "fee_type_code" do
        it "is 'first_qcontrol_without_qunav' for the beekeeper's first qcontrol" do
          service.perform
          expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
            .with { |req|
              JSON.parse(req.body)["fee"]["fee_type_code"] == "first_qcontrol_without_qunav"
            }
        end

        context "when the beekeeper has an earlier qcontrol" do
          before do
            Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
              control_date: Date.new(2024, 5, 1), fee_creation_state: "fee_ok")
          end

          it "is 'qcontrol'" do
            service.perform
            expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
              .with { |req| JSON.parse(req.body)["fee"]["fee_type_code"] == "qcontrol" }
          end
        end

        context "when with_voucher is true" do
          let(:qcontrol) do
            Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
              control_date: Date.new(2026, 5, 1), with_voucher: true,
              fee_creation_state: "fee_ok")
              .tap { |q| q.update_column(:fee_creation_state, "fee_not_created") }
          end

          it "is 'young_qcontrol', regardless of first_qcontrol?" do
            service.perform
            expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
              .with { |req| JSON.parse(req.body)["fee"]["fee_type_code"] == "young_qcontrol" }
          end

          context "and it is not the beekeeper's first qcontrol" do
            before do
              Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
                control_date: Date.new(2024, 5, 1), fee_creation_state: "fee_ok")
            end

            it "is still 'young_qcontrol'" do
              service.perform
              expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/fees")
                .with { |req| JSON.parse(req.body)["fee"]["fee_type_code"] == "young_qcontrol" }
            end
          end
        end
      end
    end

    context "when the KAS API returns a 422 error" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees")
          .to_return(status: 422, body: {error: "invalid params"}.to_json)
      end

      it "is not ok?" do
        service.perform
        expect(service).not_to be_ok
      end

      it "does not raise" do
        expect { service.perform }.not_to raise_error
      end

      it "leaves generated_fee empty" do
        service.perform
        expect(service.generated_fee).to eq({})
      end
    end

    context "when the KAS API returns a server error" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees").to_return(status: 500, body: "boom")
      end

      it "is not ok?" do
        service.perform
        expect(service).not_to be_ok
      end

      it "does not raise" do
        expect { service.perform }.not_to raise_error
      end
    end

    context "when the KAS API fails and Sentry is not defined" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees")
          .to_return(status: 422, body: {error: "invalid params"}.to_json)
        hide_const("Sentry") if defined?(Sentry)
      end

      it "does not raise" do
        expect { service.perform }.not_to raise_error
      end
    end

    context "when the KAS API fails and Sentry is defined" do
      before do
        stub_request(:post, "#{base_url}/api/v1/fees")
          .to_return(status: 422, body: {error: "invalid params"}.to_json)
      end

      it "reports the error to Sentry" do
        sentry = double("Sentry")
        stub_const("Sentry", sentry)
        allow(sentry).to receive(:capture_exception)
        service.perform
        expect(sentry).to have_received(:capture_exception)
      end
    end
  end
end
