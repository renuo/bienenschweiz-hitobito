# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe MagazineSubscriptionReportsController, type: :request do
  let(:admin) { people(:admin) }
  let(:person) { Fabricate(:magazine_subscriber) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  def subscribe(type, start_date, end_date: nil, amount: 1)
    Fabricate(:magazine_subscription, person: person, subscription_type: type,
      start_date: start_date, end_date: end_date, amount: amount,
      cancellation_reason: end_date && "kint")
  end

  def report_tables
    Nokogiri::HTML(response.body).css(".table-responsive > table")
  end

  def row_values(table, month)
    headers = table.css("thead th").map { |cell| cell.text.strip }
    row = table.css("tbody tr").find { |entry| entry.at_css("th").text.strip == month }
    headers.drop(1).zip(row.css("td").map { |cell| cell.text.to_i }).to_h
  end

  describe "#index" do
    around { |example| travel_to(Date.new(2026, 9, 15)) { example.run } }

    it "renders 18 month rows in a single table" do
      get magazine_subscription_reports_path

      expect(response).to have_http_status(:ok)
      expect(report_tables.size).to eq(1)
      months = report_tables.first.css("tbody th[scope='row']").map { |cell| cell.text.strip }
      expect(months.size).to eq(18)
      expect(months).to start_with("September 2026").and end_with("April 2025")
    end

    it "shows the paid subtotal before the individual types and highlights the WEMF columns" do
      get magazine_subscription_reports_path

      wemf = report_tables.first
      headers = ["Monat", "Bezahlte Abos", "Abo", "Abo-EUR", "Schnupper-Abo", "Online-Abo",
        "Geschenk-Abo", "Gratis-Abo", "Buchhändler-Abo", "Total"]
      expect(wemf.css("thead th").map { |cell| cell.text.strip }).to eq(headers)
      paid_header = wemf.at_css("thead th.table-primary")
      expect(paid_header.text.strip).to eq("Bezahlte Abos")
      expect(paid_header["title"]).to eq("Abo, Abo-EUR, Schnupper-Abo, Online-Abo, Geschenk-Abo")
      expect(wemf.css("thead .table-info").map { |cell| cell.text.strip })
        .to contain_exactly("Gratis-Abo", "Buchhändler-Abo")
    end

    it "shows the paid subtotal, its components and the overall total for a month" do
      subscribe("buchhaendler_abo", Date.new(2026, 7, 1), amount: 20)
      subscribe("gratis_abo", Date.new(2026, 8, 1), amount: 2)
      subscribe("abo", Date.new(2026, 9, 1), amount: 3)
      subscribe("online_abo", Date.new(2026, 9, 1))

      get magazine_subscription_reports_path

      expect(row_values(report_tables.first, "September 2026")).to eq(
        "Bezahlte Abos" => 4, "Abo" => 3, "Abo-EUR" => 0, "Gratis-Abo" => 2,
        "Schnupper-Abo" => 0, "Online-Abo" => 1, "Geschenk-Abo" => 0,
        "Buchhändler-Abo" => 20, "Total" => 26
      )
    end

    it "shows zeros when there are no subscriptions" do
      get magazine_subscription_reports_path

      expect(response).to have_http_status(:ok)
      expect(row_values(report_tables.first, "September 2026").values).to all(eq(0))
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
      subscriber = Fabricate(:magazine_subscriber, first_name: "Anna", last_name: "Muster",
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
