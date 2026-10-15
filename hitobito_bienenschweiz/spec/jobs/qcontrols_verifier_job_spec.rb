# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe QcontrolsVerifierJob do
  subject(:job) { described_class.new }

  let(:group) { groups(:aarau_und_umgebung) }
  let(:alerts) do
    ActionMailer::Base.deliveries.select { |m| m.subject == "Betriebsprüfungen ohne Entschädigung" }
  end

  before do
    service = instance_double(Kas::FeeCreationService, perform: nil, ok?: false)
    allow(Kas::FeeCreationService).to receive(:new).and_return(service)
  end

  def create_qcontrol(**attrs)
    Fabricate(:qcontrol, person: Fabricate(:person), group: group, **attrs)
  end

  describe "#perform" do
    it "sends an alert if there are qcontrols without fees" do
      create_qcontrol

      job.perform
      expect(alerts.size).to eq(1)
    end

    it "does not send an alert if all fees have been created" do
      create_qcontrol.update_columns(fee_creation_state: "fee_ok")

      job.perform
      expect(alerts).to be_empty
    end

    it "does not send an alert for qcontrols updated more than a day ago" do
      create_qcontrol.update_columns(updated_at: 2.days.ago)

      job.perform
      expect(alerts).to be_empty
    end

    %w[termination_of_business beekeeper_deceased
      resignation_from_certification_program].each do |reason|
      it "does not send an alert for qcontrols with no_control_reason #{reason}" do
        create_qcontrol.update_columns(no_control_reason: reason)

        job.perform
        expect(alerts).to be_empty
      end
    end

    it "sends an alert for qcontrols with no_control_reason no_reason" do
      create_qcontrol.update_columns(no_control_reason: "no_reason")

      job.perform
      expect(alerts.size).to eq(1)
    end

    it "does not send an alert if there are only orphaned qcontrols" do
      Fabricate(:qcontrol, person: nil, group: group)

      job.perform
      expect(alerts).to be_empty
    end

    it "does not send an alert for qcontrols referencing a non-existent person" do
      create_qcontrol.update_columns(person_id: Person.maximum(:id) + 1)

      job.perform
      expect(alerts).to be_empty
    end

    it "reschedules itself for 07:00 of the next day" do
      job.perform
      expect(job.delayed_jobs.first.run_at)
        .to eq(Time.zone.tomorrow.at_beginning_of_day.change(hour: 7))
    end
  end

  it "is scheduled by the JobManager" do
    expect(JobManager.wagon_jobs).to include(described_class)
  end
end
