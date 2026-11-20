# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe ExternalInvoiceRunsController, type: :request do
  let(:admin) { people(:admin) }
  let(:person) { Fabricate(:magazine_subscriber) }
  let(:subscription) { Fabricate(:magazine_subscription, person:) }
  let(:invoice) do
    ExternalInvoice::Magazine.create!(person:, link: subscription, state: :error,
      period_start: Date.new(2026, 12, 1))
  end
  let!(:run) do
    ExternalInvoiceRun.create!(state: :finished, started_at: 1.hour.ago, finished_at: Time.current,
      due_count: 3, created_count: 1, error_count: 2)
  end

  def log_error(subject, message, payload = nil)
    HitobitoLogEntry.create!(level: :error, category: ExternalInvoice::ERROR_CATEGORY,
      message:, payload:, subject:, external_invoice_run: run)
  end

  context "as admin" do
    before do
      roles(:admin)
      sign_in(admin)
    end

    it "lists the runs" do
      get external_invoice_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(external_invoice_run_path(run))
    end

    it "shows the errors with links to person and subscriptions" do
      log_error(invoice, "Rechnung konnte nicht in Abacus erstellt werden", {"status" => 400})
      log_error(subscription, "Unerwarteter Fehler", {"error" => "NoMethodError: boom"})

      get external_invoice_run_path(run)

      expect(response).to have_http_status(:ok)
      html = Nokogiri::HTML(response.body)
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(2)
      expect(html.css("a[href='#{person_path(person)}']").size).to eq(2)
      expect(response.body).to include(
        group_person_magazine_subscriptions_path(person.primary_group_id, person)
      )
      expect(response.body).to include("NoMethodError: boom")
      expect(response.body).to include("01.12.2026")
    end
  end

  context "as root" do
    before { sign_in(Fabricate(:person, email: Settings.root_email)) }

    it "lists the runs without actions for unsupported routes" do
      get external_invoice_runs_path

      expect(response).to have_http_status(:ok)
    end
  end

  context "as other person" do
    before { sign_in(person) }

    it "cannot list the runs" do
      expect { get external_invoice_runs_path }.to raise_error(CanCan::AccessDenied)
    end

    it "cannot show a run" do
      expect { get external_invoice_run_path(run) }.to raise_error(CanCan::AccessDenied)
    end
  end
end
