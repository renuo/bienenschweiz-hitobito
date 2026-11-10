# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"
require "rake"

describe "help_texts rake tasks" do
  before(:all) do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    unless Rake::Task.task_defined?("help_texts:export")
      load HitobitoBienenschweiz::Wagon.root.join("lib", "tasks", "help_texts.rake").to_s
    end
  end

  let(:path) { Rails.root.join("tmp", "help_texts_spec.yml") }

  after { FileUtils.rm_f(path) }

  def run(name, *args)
    task = Rake::Task["help_texts:#{name}"]
    task.reenable
    task.invoke(*args)
  end

  def export_yaml
    stdout = StringIO.new
    original, $stdout = $stdout, stdout
    run(:export)
    stdout.string
  ensure
    $stdout = original
  end

  def create_help_text(controller:, model:, kind:, name:, bodies:, start_open: false)
    help_text = HelpText.new(context: "#{controller}--#{model}", key: "#{kind}.#{name}",
      start_open: start_open)
    bodies.each { |locale, html| Globalize.with_locale(locale) { help_text.body = html } }
    Globalize.with_locale(bodies.keys.first) { help_text.save! }
    help_text.translations.each do |translation|
      translation.help_text_id = help_text.id
      translation.save!
    end
    help_text
  end

  def body(help_text, locale)
    Globalize.with_locale(locale) { help_text.reload.body.to_s }
  end

  it "round-trips help texts with all translations" do
    create_help_text(controller: "people", model: "person", kind: "field", name: "birthday",
      start_open: true, bodies: {de: "<div>Geburtstag</div>", fr: "<div>Anniversaire</div>"})
    edit = create_help_text(controller: "groups", model: "group", kind: "action", name: "edit",
      bodies: {de: "<div>Bearbeiten</div>"})
    HelpText::Translation.create!(help_text_id: edit.id, locale: "it")

    yaml = export_yaml
    entries = YAML.safe_load(yaml)["help_texts"]
    expect(entries.pluck("controller")).to eq %w[groups people]
    expect(entries.first["body"].keys).to eq %w[de]

    path.write(yaml)
    HelpText.destroy_all
    expect(ActionText::RichText.where(record_type: "HelpText::Translation")).to be_empty

    expect { run(:import, path.to_s) }.to output(/Imported 2 help texts/).to_stderr

    birthday = HelpText.find_by!(controller: "people", model: "person", kind: "field",
      name: "birthday")
    expect(birthday.start_open).to be true
    expect(body(birthday, :de)).to include "Geburtstag"
    expect(body(birthday, :fr)).to include "Anniversaire"
    expect(export_yaml).to eq yaml
  end

  it "updates existing help texts and removes the ones missing from the file" do
    kept = create_help_text(controller: "people", model: "person", kind: "field",
      name: "birthday", bodies: {de: "<div>alt</div>", fr: "<div>vieux</div>"})
    create_help_text(controller: "groups", model: "group", kind: "action", name: "edit",
      bodies: {de: "<div>weg</div>"})

    allow($stdin).to receive(:read).and_return({"help_texts" => [{
      "controller" => "people", "model" => "person", "kind" => "field", "name" => "birthday",
      "start_open" => true, "body" => {"de" => "<div>neu</div>"}
    }]}.to_yaml)

    expect { run(:import) }.to output(/Imported 1 help texts/).to_stderr

    expect(HelpText.pluck(:id)).to eq [kept.id]
    expect(kept.reload.start_open).to be true
    expect(body(kept, :de)).to include "neu"
    expect(kept.translations.pluck(:locale)).to eq ["de"]
  end
end
