# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe MagazineSubscriptionsController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:admin) { people(:admin) }
  let(:person) { Fabricate(:person) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#index" do
    let!(:subscriptions) do
      [
        Fabricate(:magazine_subscription, person: person, subscription_type: "abo",
          start_date: Date.new(2024, 1, 1)),
        Fabricate(:magazine_subscription, person: person, subscription_type: "online_abo",
          start_date: Date.new(2026, 3, 1), end_date: Date.new(2026, 8, 31),
          cancellation_reason: "Umzug ins Ausland", amount: 3)
      ]
    end

    it "lists the subscriptions of the person" do
      get group_person_magazine_subscriptions_path(sektion, person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Abo")
      expect(response.body).to include("Online-Abo")
      expect(response.body).to include("Umzug ins Ausland")
      expect(response.body).to include("31.08.2026")
    end
  end

  describe "#new" do
    it "renders the form with all subscription types" do
      get new_group_person_magazine_subscription_path(sektion, person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Abomodell")
      expect(response.body).to include("Abbestellungsgrund")
      MagazineSubscription.subscription_type_labels.each_value do |label|
        expect(response.body).to include(label)
      end
    end

    def field(name)
      response.body[/<input[^>]*name="magazine_subscription\[#{name}\]"[^>]*>/]
    end

    it "prefills the start date with the first of next month" do
      get new_group_person_magazine_subscription_path(sektion, person)

      first_of_next_month = Time.zone.today.beginning_of_month.next_month
      expect(field(:start_date)).to include(%(value="#{I18n.l(first_of_next_month)}"))
    end

    it "still defaults to the first of next month at the end of a long month" do
      travel_to(Date.new(2026, 1, 31)) do
        get new_group_person_magazine_subscription_path(sektion, person)

        expect(field(:start_date)).to include(%(value="01.02.2026"))
      end
    end

    it "leaves the end date empty" do
      get new_group_person_magazine_subscription_path(sektion, person)

      expect(field(:end_date)).not_to include("value=")
    end

    it "shows the Bienen Abo tab as active" do
      get new_group_person_magazine_subscription_path(sektion, person)

      expect(response.body).to match(/<li class="active"[^>]*>.*Bienen Abo.*<\/li>/m)
    end
  end

  describe "#create" do
    let(:params) do
      {start_date: "01.05.2026", subscription_type: "geschenk_abo", amount: 2}
    end

    it "creates a subscription for the person" do
      expect do
        post group_person_magazine_subscriptions_path(sektion, person),
          params: {magazine_subscription: params}
      end.to change { MagazineSubscription.count }.by(1)

      subscription = MagazineSubscription.last
      expect(subscription.person).to eq(person)
      expect(subscription.start_date).to eq(Date.new(2026, 5, 1))
      expect(subscription.subscription_type).to eq("geschenk_abo")
      expect(subscription.amount).to eq(2)
      expect(subscription.end_date).to be_nil
    end

    it "redirects to the index after creation" do
      post group_person_magazine_subscriptions_path(sektion, person),
        params: {magazine_subscription: params}

      expect(response.location)
        .to include(group_person_magazine_subscriptions_path(sektion, person))
    end

    context "with invalid params" do
      it "does not create a subscription and renders the form with errors" do
        expect do
          post group_person_magazine_subscriptions_path(sektion, person),
            params: {magazine_subscription: {start_date: "", subscription_type: "", amount: ""}}
        end.not_to change { MagazineSubscription.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("muss ausgefüllt werden")
      end
    end

    context "when the required fields are submitted blank" do
      # what the browser posts once the prefilled start date is cleared: the type select
      # sits on its blank prompt and amount still carries the column default
      let(:empty_form_params) do
        {subscription_type: "", start_date: "", end_date: "", amount: "1",
         cancellation_reason: ""}
      end

      it "reports the missing fields instead of hitting the not-null constraint" do
        expect do
          post group_person_magazine_subscriptions_path(sektion, person),
            params: {magazine_subscription: empty_form_params}
        end.not_to change { MagazineSubscription.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Startdatum muss ausgefüllt werden")
        expect(response.body).to include("Abomodell muss ausgefüllt werden")
      end

      it "reports each missing field exactly once" do
        post group_person_magazine_subscriptions_path(sektion, person),
          params: {magazine_subscription: empty_form_params}

        expect(response.body.scan("Startdatum muss ausgefüllt werden").size).to eq(1)
        expect(response.body.scan("Abomodell muss ausgefüllt werden").size).to eq(1)
      end
    end
  end

  describe "#edit" do
    let!(:subscription) { Fabricate(:magazine_subscription, person: person) }

    it "renders the edit form" do
      get edit_group_person_magazine_subscription_path(sektion, person, subscription)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Abomodell")
    end
  end

  describe "#update" do
    let!(:subscription) do
      Fabricate(:magazine_subscription, person: person, subscription_type: "abo")
    end

    let(:params) do
      {subscription_type: "gratis_abo", amount: 5, end_date: "31.12.2026",
       cancellation_reason: "Kein Interesse mehr"}
    end

    it "updates the subscription" do
      patch group_person_magazine_subscription_path(sektion, person, subscription),
        params: {magazine_subscription: params}

      subscription.reload
      expect(subscription.subscription_type).to eq("gratis_abo")
      expect(subscription.amount).to eq(5)
      expect(subscription.end_date).to eq(Date.new(2026, 12, 31))
      expect(subscription.cancellation_reason).to eq("Kein Interesse mehr")
    end

    it "redirects to the index after update" do
      patch group_person_magazine_subscription_path(sektion, person, subscription),
        params: {magazine_subscription: {subscription_type: "gratis_abo"}}

      expect(response.location)
        .to include(group_person_magazine_subscriptions_path(sektion, person))
    end
  end

  describe "#destroy" do
    let!(:subscription) { Fabricate(:magazine_subscription, person: person) }

    it "destroys the subscription" do
      expect do
        delete group_person_magazine_subscription_path(sektion, person, subscription)
      end.to change { MagazineSubscription.count }.by(-1)
    end

    it "redirects to the index after deletion" do
      delete group_person_magazine_subscription_path(sektion, person, subscription)

      expect(response.location)
        .to include(group_person_magazine_subscriptions_path(sektion, person))
    end
  end

  describe "tab visibility" do
    it "shows the tab to admins" do
      get group_person_path(groups(:root), admin)

      expect(response.body).to include("Bienen Abo")
    end

    it "hides the tab from non-admins with read access" do
      president = Fabricate(Group::SektionVorstand::Praesident.sti_name.to_sym,
        group: groups(:vorstand_379)).person
      sign_in(president)

      get group_person_path(groups(:vorstand_379), president)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(president.full_name)
      expect(response.body).not_to include("Bienen Abo")
    end
  end

  describe "authorization" do
    context "as a non-admin person" do
      before { sign_in(Fabricate(:person)) }

      it "denies index access" do
        expect do
          get group_person_magazine_subscriptions_path(sektion, person)
        end.to raise_error(CanCan::AccessDenied)
      end

      it "denies create access" do
        expect do
          post group_person_magazine_subscriptions_path(sektion, person),
            params: {magazine_subscription: {start_date: "01.05.2026", subscription_type: "abo"}}
        end.to raise_error(CanCan::AccessDenied)
      end

      it "denies destroy access" do
        subscription = Fabricate(:magazine_subscription, person: person)

        expect do
          delete group_person_magazine_subscription_path(sektion, person, subscription)
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
