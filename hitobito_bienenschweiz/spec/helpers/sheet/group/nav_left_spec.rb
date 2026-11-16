# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

require "spec_helper"

describe "Sheet::Group::NavLeft" do
  let(:group) { groups(:aarau_und_umgebung) }
  let(:sheet) { Sheet::Group.new(self, nil, group) }
  let(:nav) { Sheet::Group::NavLeft.new(sheet) }

  let(:request) { ActionController::TestRequest.create({}) }

  subject(:html) { Capybara::Node::Simple.new(nav.render) }

  def can?(*_args)
    true
  end

  it "lists the sub groups alphabetically, followed by the inactive roles" do
    expect(html.all(".nav-left-list > li > a").map(&:text))
      .to eq(["Administrator", "Fachpersonen", "Vorstand", "Inaktive Rollen"])
  end
end
