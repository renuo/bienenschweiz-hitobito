# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"
require "rake"

RSpec::Matchers.define_negated_matcher :not_change, :change

describe Bienenschweiz::IntegrationsRestore do
  let(:kantonalverband) { groups(:aargauer_kantonalverband) }

  let(:app_attrs) do
    {"name" => "Shop", "uid" => "shop-uid", "secret" => "shop-secret",
     "redirect_uri" => "https://shop.example.com/callback", "scopes" => "openid email",
     "skip_consent_screen" => true, "cors_origins" => ["https://shop.example.com"]}
  end
  let(:token_attrs) do
    {"name" => "Website", "token" => "website-token", "permission" => "layer_and_below_read",
     "people" => true, "layer_group_code" => "42", "layer_group_name" => "ignored",
     "cors_origins" => []}
  end

  def json = {oauth_applications: [app_attrs], service_tokens: [token_attrs]}.to_json

  before do
    kantonalverband.update_column(:code, 42)
    allow($stdout).to receive(:puts)
  end

  subject(:restore) { described_class.new(json).run }

  it "creates applications and tokens with the given credentials" do
    expect { restore }.to change { Oauth::Application.count }.by(1)
      .and change { ServiceToken.count }.by(1)

    app = Oauth::Application.find_by!(uid: "shop-uid")
    expect(app.secret).to eq "shop-secret"
    expect(app.skip_consent_screen).to be true
    expect(app.cors_origins.map(&:origin)).to eq ["https://shop.example.com"]

    token = ServiceToken.find_by!(token: "website-token")
    expect(token.layer).to eq kantonalverband
    expect(token.permission).to eq "layer_and_below_read"
    expect(token.people).to be true
  end

  it "is idempotent and updates existing records" do
    restore
    app_attrs["redirect_uri"] = "https://shop.example.com/new"
    app_attrs["cors_origins"] = ["https://other.example.com"]
    token_attrs["permission"] = "layer_read"
    token_attrs["cors_origins"] = ["https://website.example.com"]

    expect { described_class.new(json).run }.to not_change { Oauth::Application.count }
      .and not_change { ServiceToken.count }
    app = Oauth::Application.find_by!(uid: "shop-uid")
    expect(app.redirect_uri).to eq "https://shop.example.com/new"
    expect(app.cors_origins.map(&:origin)).to eq ["https://other.example.com"]
    token = ServiceToken.find_by!(token: "website-token")
    expect(token.permission).to eq "layer_read"
    expect(token.cors_origins.map(&:origin)).to eq ["https://website.example.com"]
  end

  it "leaves records that are not part of the JSON untouched" do
    other_app = Oauth::Application.create!(name: "Other", redirect_uri: "https://other.example.com/cb")
    other_token = ServiceToken.create!(name: "Other", layer: groups(:root))

    restore

    expect(other_app.reload.name).to eq "Other"
    expect(other_token.reload.name).to eq "Other"
  end

  it "accepts JSON with missing sections" do
    expect { described_class.new("{}").run }.not_to change { ServiceToken.count }
  end

  it "finds the layer by name when it has no code" do
    token_attrs.merge!("layer_group_code" => nil, "layer_group_name" => groups(:root).name)
    restore
    expect(ServiceToken.find_by!(token: "website-token").layer).to eq groups(:root)
  end

  it "fails without changes when the layer does not exist" do
    token_attrs["layer_group_code"] = "999"
    expect { restore }.to raise_error(ActiveRecord::RecordNotFound, /999/)
    expect(Oauth::Application.find_by(uid: "shop-uid")).to be_nil
  end

  it "restores what integrations:dump produced" do
    restore
    Rails.application.load_tasks unless Rake::Task.task_defined?("integrations:dump")
    dumped = StringIO.new
    allow($stdout).to receive(:puts) { |line| dumped.puts(line) }
    Rake::Task["integrations:dump"].execute

    Oauth::Application.destroy_all
    ServiceToken.destroy_all
    described_class.new(dumped.string).run

    expect(Oauth::Application.find_by!(uid: "shop-uid").secret).to eq "shop-secret"
    expect(ServiceToken.find_by!(token: "website-token").layer).to eq kantonalverband
  end
end
