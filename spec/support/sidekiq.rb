require 'sidekiq/util'
Sidekiq.logger.level = Logger::ERROR

require 'rspec-redis_helper'
RSpec::RedisHelper::CONFIG = { :url => 'redis://localhost/15', :namespace => 'testy' }

require 'sidekiq/redis_connection'
REDIS = Sidekiq::RedisConnection.create(RSpec::RedisHelper::CONFIG)

RSpec.configure do |spec|
  spec.include RSpec::RedisHelper, redis: true

  # clean the Redis database around each run
  # @see https://www.relishapp.com/rspec/rspec-core/docs/hooks/around-hooks
  spec.around( :each, redis: true ) do |example|
    with_clean_redis do
      example.run
    end
  end
end