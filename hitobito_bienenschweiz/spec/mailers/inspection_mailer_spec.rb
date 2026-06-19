# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe InspectionMailer do
  let(:sektion) { Fabricate(:sektion) }
  let(:person) { Fabricate(:person, first_name: "Hans", last_name: "Imker") }
  let(:inspector) { Fabricate(:person, first_name: "Max", last_name: "Prüfer") }
  let(:qcontrol) do
    Fabricate(:qcontrol, person: person, inspector: inspector, group: sektion,
      control_state: "not_passed")
  end

  before do
    stub_const("InspectionMailer::APP_NOTIFICATIONS_EMAIL", "secretary@example.com")
  end

  describe "#inspection_failed_mailer" do
    subject(:mail) { InspectionMailer.inspection_failed_mailer(qcontrol.id) }

    it "sends to APP_NOTIFICATIONS_EMAIL" do
      expect(mail.to).to eq(["secretary@example.com"])
    end

    it "has the correct subject containing the person's name" do
      expect(mail.subject).to eq(I18n.t("inspection_failed.subject", name: person.full_name))
    end

    it "includes the inspector's name in the body" do
      expect(mail.body.encoded).to include(inspector.full_name)
    end

    it "includes the beekeeper's name in the body" do
      expect(mail.body.encoded).to include(person.full_name)
    end

    it "includes a link to the inspector" do
      expect(mail.body.encoded).to include(person_url(inspector))
    end

    it "includes a link to the beekeeper" do
      expect(mail.body.encoded).to include(person_url(person))
    end
  end
end
