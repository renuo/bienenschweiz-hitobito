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
