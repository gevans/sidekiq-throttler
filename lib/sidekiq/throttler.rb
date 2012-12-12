require 'sidekiq'
require 'active_support'
require 'active_support/core_ext'

require 'sidekiq/throttler/version'
require 'sidekiq/throttler/rate_limit'

module Sidekiq
  class Throttler
  end # Throttler
end # Sidekiq