# move uploads out of the public folder by de
# fault!
Rails.application.config.to_prepare do
  require 'carrierwave'
  require 'carrierwave-aws'
  CarrierWave.configure do |config|
    config.storage = :aws
    config.aws_bucket = ENV['UPLOADS_AWS_BUCKET_NAME']
    # config.aws_acl    = 'public-read'
    config.asset_host = "https://s3.eu-central-1.amazonaws.com/#{ENV['UPLOADS_AWS_BUCKET_NAME']}"
    config.aws_credentials = {
      access_key_id: ENV['UPLOADS_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['UPLOADS_AWS_SECRET_ACCESS_KEY'],
      region: 'eu-central-1'
    }
  end
end
