# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe HealthzController, type: :request do
  let(:json) { JSON.parse(response.body) }

  before do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:read).and_call_original
    stub_file_read("/sys/fs/cgroup/memory.max", "2000000")
    stub_file_read("/sys/fs/cgroup/memory.current", "1500000")
    stub_file_read("/sys/fs/cgroup/memory.stat", "inactive_file 100000")
    allow(Truemail).to receive(:valid?).and_return(true)
  end

  describe "GET /healthz" do
    context "when heartbeat is disabled (non-production)" do
      before { allow(Delayed::Heartbeat.configuration).to receive(:enabled?).and_return(false) }

      it "reports worker_running: true and returns 200" do
        get "/healthz"

        expect(response.status).to eq(200)
        expect(json.dig("app_status", "details", "worker_running")).to be true
      end
    end

    context "when heartbeat is enabled and a live worker exists" do
      before do
        allow(Delayed::Heartbeat.configuration).to receive(:enabled?).and_return(true)
        allow(Delayed::Heartbeat.configuration)
          .to receive(:heartbeat_timeout_seconds).and_return(180)
        allow(Delayed::Heartbeat::Worker).to receive(:where).and_call_original
        allow(Delayed::Heartbeat::Worker).to receive(:where)
          .with("last_heartbeat_at >= ?", anything)
          .and_return(double(exists?: true))
      end

      it "reports worker_running: true and returns 200" do
        get "/healthz"

        expect(response.status).to eq(200)
        expect(json.dig("app_status", "details", "worker_running")).to be true
      end
    end

    context "when heartbeat is enabled but no live worker exists" do
      before do
        allow(Delayed::Heartbeat.configuration).to receive(:enabled?).and_return(true)
        allow(Delayed::Heartbeat.configuration)
          .to receive(:heartbeat_timeout_seconds).and_return(180)
        allow(Delayed::Heartbeat::Worker).to receive(:where).and_call_original
        allow(Delayed::Heartbeat::Worker).to receive(:where)
          .with("last_heartbeat_at >= ?", anything)
          .and_return(double(exists?: false))
      end

      it "reports worker_running: false and returns 503" do
        get "/healthz"

        expect(response.status).to eq(503)
        expect(json.dig("app_status", "details", "worker_running")).to be false
      end
    end
  end

  def stub_file_read(file, content)
    allow(File).to receive(:exist?).with(file).and_return(true)
    allow(File).to receive(:read).with(file).and_return(content)
  end
end
