# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::MagazineSubscriptionInvoice do
  describe "configured articles" do
    it "invoices the EURO abo with the EURO article and other billable types with abo-biez" do
      expect(described_class.article(:abo_eur)[:article_number]).to eq("abo-biez-EURO")
      (described_class.billable_types - ["abo_eur"]).each do |type|
        expect(described_class.article(type)[:article_number]).to eq("abo-biez")
      end
    end

    it "only bills paid subscription types" do
      expect(described_class.billable_types).to match_array(%w[abo abo_eur online_abo geschenk_abo])
    end
  end

  describe "#person" do
    let(:subscription) { Fabricate.build(:magazine_subscription) }

    it "is the subscriber" do
      expect(described_class.new(subscription, Time.zone.today).person)
        .to eq(subscription.person)
    end

    it "is the gifter for gift subscriptions" do
      gifter = Fabricate.build(:person)
      subscription.assign_attributes(subscription_type: "geschenk_abo", gifter:)

      expect(described_class.new(subscription, Time.zone.today).person).to eq(gifter)
    end
  end

  describe ".article" do
    before do
      allow(Settings.magazine_subscription_invoicing).to receive_messages(
        articles: {abo_biez: {article_number: "abo-biez"}},
        subscription_type_articles: {abo: "abo_biez", online_abo: "missing"}
      )
    end

    it "returns the article the subscription type is mapped to" do
      expect(described_class.article("abo")).to eq(article_number: "abo-biez")
    end

    it "is nil for an unknown article or unmapped type" do
      expect(described_class.article("online_abo")).to be_nil
      expect(described_class.article("gratis_abo")).to be_nil
    end
  end
end
