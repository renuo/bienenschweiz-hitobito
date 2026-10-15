# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe QcontrolsMailer do
  let(:group) { groups(:aarau_und_umgebung) }
  let(:person) { Fabricate(:person, first_name: "Maja", last_name: "Biene") }
  let!(:qcontrol) { Fabricate(:qcontrol, person: person, group: group, title: "Kontrolle") }

  subject(:mail) { described_class.without_fee_alert(Qcontrol.needs_fee_creation) }

  before do
    stub_const("QcontrolsMailer::SECRETARY_EMAIL", "secretary@example.com")
    stub_const("QcontrolsMailer::DEVELOPER_EMAIL", "developer@example.com")
    service = instance_double(Kas::FeeCreationService, perform: nil, ok?: false)
    allow(Kas::FeeCreationService).to receive(:new).and_return(service)
  end

  it "sends the email to the secretary with the developer in cc" do
    expect(mail.to).to eq(["secretary@example.com"])
    expect(mail.cc).to eq(["developer@example.com"])
    expect(mail.subject).to eq("Betriebsprüfungen ohne Entschädigung")
  end

  it "lists the qcontrols without fee" do
    body = mail.body.to_s
    expect(body).to include("derzeit 1 Betriebsprüfungen")
    expect(body).to include(qcontrol.to_s, group.to_s, "Maja Biene", "/people/#{person.id}")
    expect(body).to include("/orphan_qcontrols")
  end

  it "mentions qcontrols for which the fee creation failed" do
    expect(mail.body.to_s).to include("1 davon haben beim Versuch, die Spese zu generieren")
  end

  it "does not mention failures for qcontrols not eligible for a fee" do
    qcontrol.update_columns(inspector_id: nil)
    expect(mail.body.to_s).not_to include("die Spese zu generieren")
  end

  it "mentions orphaned qcontrols" do
    Fabricate(:qcontrol, person: nil, group: group)
    expect(mail.body.to_s).to include("Zusätzlich gibt es 1 Betriebsprüfungen ohne")
  end

  it "does not mention orphaned qcontrols if there are none" do
    expect(mail.body.to_s).not_to include("ohne dazugehörenden Siegelimker")
  end
end
