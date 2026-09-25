# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe MagazineSubscriptionReportsController, type: :request do
  let(:admin) { people(:admin) }
  let(:person) { Fabricate(:person) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  def subscribe(type, start_date, end_date: nil, amount: 1)
    Fabricate(:magazine_subscription, person: person, subscription_type: type,
      start_date: start_date, end_date: end_date, amount: amount)
  end

  # the row a category renders as, without its leading label cell
  def row_values(label)
    row = response.body[/<tr>\s*<t[dh]>\s*#{Regexp.escape(label)}\s*<\/t[dh]>.*?<\/tr>/m]
    row.to_s.scan(/<t[dh][^>]*>\s*(\d+)\s*<\/t[dh]>/).flatten.map(&:to_i)
  end

  describe "#index" do
    around { |example| travel_to(Date.new(2026, 9, 15)) { example.run } }

    it "renders the three reported months as columns" do
      get magazine_subscription_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Juli 2026", "August 2026", "September 2026")
    end

    it "renders a row per category and a total row" do
      get magazine_subscription_reports_path

      expect(response.body).to include("Buchhändler-Abos", "Gratis-Abos", "Bezahlte Abos", "Total")
    end

    it "reports the Anzahl per category and month" do
      subscribe("buchhaendler_abo", Date.new(2026, 7, 1), amount: 20)
      subscribe("gratis_abo", Date.new(2026, 8, 1), amount: 2)
      subscribe("abo", Date.new(2026, 9, 1), amount: 3)
      subscribe("online_abo", Date.new(2026, 9, 1))

      get magazine_subscription_reports_path

      expect(row_values("Buchhändler-Abos")).to eq([20, 20, 20])
      expect(row_values("Gratis-Abos")).to eq([0, 2, 2])
      expect(row_values("Bezahlte Abos")).to eq([0, 0, 4])
    end

    it "totals every category per month" do
      subscribe("buchhaendler_abo", Date.new(2026, 8, 1), amount: 20)
      subscribe("gratis_abo", Date.new(2026, 8, 1), amount: 2)
      subscribe("abo", Date.new(2026, 9, 1), amount: 3)

      get magazine_subscription_reports_path

      expect(row_values("Total")).to eq([0, 22, 25])
    end

    it "shows zeros when there are no subscriptions" do
      get magazine_subscription_reports_path

      expect(response).to have_http_status(:ok)
      expect(row_values("Total")).to eq([0, 0, 0])
    end

    it "links the report from the admin navigation" do
      get admin_path

      expect(response.body).to include(magazine_subscription_reports_path)
      expect(response.body).to include("Bienen Abo Statistik")
    end
  end

  describe "#export" do
    around { |example| travel_to(Date.new(2026, 9, 23)) { example.run } }

    def csv
      CSV.parse(response.body.delete_prefix("\uFEFF"), col_sep: ";")
    end

    it "sends a CSV attachment named after the export date" do
      get export_magazine_subscription_reports_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.headers["Content-Disposition"]).to include("bienen-abos_2026-09-23.csv")
    end

    it "exports one row per subscriber with address, Abos and total" do
      subscriber = Fabricate(:person, first_name: "Anna", last_name: "Muster",
        street: "Bienenweg", housenumber: "7b", zip_code: "3000", town: "Bern")
      subscribe("abo", Date.new(2026, 1, 1), amount: 2)
      Fabricate(:magazine_subscription, person: subscriber, subscription_type: "gratis_abo",
        start_date: Date.new(2026, 1, 1), amount: 1)
      Fabricate(:magazine_subscription, person: subscriber, subscription_type: "abo",
        start_date: Date.new(2026, 1, 1), amount: 4)

      get export_magazine_subscription_reports_path

      row = csv.find { |values| values.include?("Muster") }
      expect(csv.size).to eq(3) # header + the two subscribers
      expect(row).to include("Anna", "Bienenweg", "7b", "3000", "Bern", "Abo (4), Gratis-Abo (1)",
        "5")
    end

    it "leaves out people whose subscriptions have ended" do
      subscribe("abo", Date.new(2026, 1, 1), end_date: Date.new(2026, 8, 31))

      get export_magazine_subscription_reports_path

      expect(csv.size).to eq(1) # header only
    end

    it "is offered as a link on the report page" do
      get magazine_subscription_reports_path

      expect(response.body).to include(export_magazine_subscription_reports_path)
    end
  end

  describe "authorization" do
    it "denies access to non-admins" do
      sign_in(Fabricate(:person))

      expect do
        get magazine_subscription_reports_path
      end.to raise_error(CanCan::AccessDenied)
    end

    it "denies the export to non-admins" do
      sign_in(Fabricate(:person))

      expect do
        get export_magazine_subscription_reports_path
      end.to raise_error(CanCan::AccessDenied)
    end

    it "hides the admin navigation entry from non-admins" do
      president = Fabricate(Group::SektionVorstand::Praesident.sti_name.to_sym,
        group: groups(:vorstand_379)).person
      sign_in(president)

      get group_person_path(groups(:vorstand_379), president)

      expect(response.body).not_to include("Bienen Abo Statistik")
    end
  end
end
