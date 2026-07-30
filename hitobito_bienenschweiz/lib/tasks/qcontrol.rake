# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

def qcontrol_find_inspector(inspector_id)
  if inspector_id.present?
    inspector = Person.find_by(id: inspector_id)
    abort "Person ##{inspector_id} not found" unless inspector
    unless inspector.qcontrol_inspector?
      abort "#{inspector} does not have a qcontrol inspector role"
    end
  else
    inspector = Person.joins(:roles)
      .where(roles: {type: Bienenschweiz::Person::QCONTROLLER_ROLES})
      .merge(Role.active)
      .distinct
      .detect { |person| person.inspectable_beekeepers.exists? }
    abort "No qcontrol inspector with an inspectable beekeeper was found" unless inspector
  end
  inspector
end

def qcontrol_find_beekeeper(inspector, beekeeper_id)
  if beekeeper_id.present?
    beekeeper = inspector.inspectable_beekeepers.find_by(id: beekeeper_id)
    unless beekeeper
      abort "#{inspector} is not permitted to inspect beekeeper ##{beekeeper_id}"
    end
  else
    beekeeper = inspector.inspectable_beekeepers.first
    abort "#{inspector} has no beekeeper to inspect" unless beekeeper
  end
  beekeeper
end

namespace :qcontrol do
  desc "Print a curl command that creates a Qcontrol via the mobile API's " \
       "InspectionsController.\n" \
       "The access token is generated for inspector_id, or, if omitted, for the first " \
       "qcontrol inspector who has a beekeeper they are allowed to inspect.\n" \
       "beekeeper_id defaults to one of that inspector's inspectable beekeepers.\n" \
       "Usage: rake qcontrol:create_curl[inspector_id,beekeeper_id,control_date,host]"
  task :create_curl,
    [:inspector_id, :beekeeper_id, :control_date, :host] => :environment do |_, args|
    control_date = args[:control_date] || Time.zone.today.iso8601
    host = args[:host] || "#{Settings.application.protocol}://#{Settings.application.hostname}"

    inspector = qcontrol_find_inspector(args[:inspector_id])
    beekeeper = qcontrol_find_beekeeper(inspector, args[:beekeeper_id])
    access_token = inspector.beeaudit_authentication_token

    body = {
      inspection: {
        title: "Betriebsprüfung #{beekeeper}",
        control_date: control_date,
        no_control_reason: "no_reason",
        with_voucher: false
      }
    }.to_json

    url = "#{host}/api/mobile/v1/beekeepers/#{beekeeper.id}/inspections"

    puts <<~CURL
      curl -X POST '#{url}' \\
        -H 'Content-Type: application/json' \\
        -H 'Access-Token: #{access_token}' \\
        -d '#{body}'
    CURL
  end
end
