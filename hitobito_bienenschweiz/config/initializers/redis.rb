# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


if ENV['RAILS_CACHE_REDIS_URL'] && ENV['NINE_KVS_REDIS_CA_CERT']
  custom_cert_store = OpenSSL::X509::Store.new.tap do |store|
    store.add_cert(OpenSSL::X509::Certificate.new(ENV['NINE_KVS_REDIS_CA_CERT']))
  end

  Rails.application.config.cache_store = :redis_cache_store, {
    url: ENV['RAILS_CACHE_REDIS_URL'],
    ssl_params: {
      verify_mode: OpenSSL::SSL::VERIFY_PEER,
      cert_store:  custom_cert_store
    }
  }
  Rails.cache = ActiveSupport::Cache.lookup_store(Rails.application.config.cache_store)
end
