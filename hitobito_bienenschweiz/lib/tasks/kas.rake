# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

namespace :kas do
  desc "Create a sample fee via the KAS REST API\n" \
       "Usage: rake kas:create_sample_fee[user_id,group_id,fee_type_code,occurred_on,total_amount]"
  task :create_sample_fee,
    [:user_id, :group_id, :fee_type_code, :occurred_on, :total_amount] => :environment do |_, args|
    user_id = args[:user_id] or abort "Missing required argument: user_id"
    group_id = args[:group_id] or abort "Missing required argument: group_id"

    fee_params = {
      user_id: user_id.to_i,
      quantity: 1,
      fee_type_code: args[:fee_type_code] || "qcontrol",
      occurred_on: args[:occurred_on] || Time.zone.today.iso8601,
      total_amount: args[:total_amount] || "100.00",
      group_id: group_id
    }

    puts "Creating sample fee: #{fee_params.inspect}"
    result = KasClient.new.create_fee(fee_params)
    puts "Fee created successfully: #{result.inspect}"
  rescue KasClient::Error => e
    abort "KAS API error: #{e.message}"
  end
end
