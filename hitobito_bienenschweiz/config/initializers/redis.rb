ssl_context = OpenSSL::SSL::SSLContext.new.tap do |ctx|
  ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
  # This adds the cert directly from the string to the context's store
  ctx.cert_store = OpenSSL::X509::Store.new.tap { |s| s.add_cert(OpenSSL::X509::Certificate.new(ENV['NINE_KVS_REDIS_CA_CERT'])) }
end

Rails.application.config.cache_store = :redis_cache_store, {
  url: ENV['RAILS_CACHE_REDIS_URL'],
  ssl_params: { ssl_context: ssl_context }
}
