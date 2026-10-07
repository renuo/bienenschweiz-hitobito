# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe TrialSubscriptionMailer, type: :mailer do
  let(:subscription) { Fabricate(:magazine_subscription, amount: 3) }
  let(:person) { subscription.person }

  it "explains the scenario and links to the person for the secretary" do
    stub_const("ENV", ENV.to_h.merge("SECRETARY_EMAIL" => "secretary@example.com"))
    mail = described_class.manual_review(person, [subscription])

    expect(mail.to).to eq(["secretary@example.com"])
    expect(mail.subject).to include(person.full_name)
    expect(mail.body.decoded).to include("3 Exemplar(e)", "manuelle", "unbefristet")
    expect(mail.body.encoded).to include("/people/#{person.id}")
  end

  it "lists every subscription, including its type, copies and termination date" do
    subscription.update!(end_date: Date.new(2027, 2, 28), cancellation_reason: "kint")
    second = Fabricate(:magazine_subscription, person: person, subscription_type: "abo_eur")
    mail = described_class.manual_review(person, [subscription, second])

    expect(mail.body.decoded).to include("Abo-EUR", "3 Exemplar(e)", "1 Exemplar(e)",
      I18n.l(subscription.start_date), I18n.l(subscription.end_date), "unbefristet")
    expect(mail.body.decoded).to include("keine Abonnemente automatisch geändert oder erstellt")
  end
end
