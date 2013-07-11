require 'sidekiq'
require 'active_support/core_ext/numeric/time'

require 'sidekiq/throttler/version'
require 'sidekiq/throttler/rate_limit'

module Sidekiq
  ##
  # Sidekiq server middleware. Throttles jobs when they exceed limits specified
  # on the worker. Jobs that exceed the limit are requeued with a delay.
  class Throttler

    ##
    # Passes the worker, arguments, and queue to {RateLimit} and either yields
    # or requeues the job depending on whether the worker is throttled.
    #
    # @param [Sidekiq::Worker] worker
    #   The worker the job belongs to.
    #
    # @param [Hash] msg
    #   The job message.
    #
    # @param [String] queue
    #   The current queue.
    def call(worker, msg, queue)
      rate_limit = RateLimit.new(worker, msg['args'], queue)

      rate_limit.within_bounds do
        yield
      end

      rate_limit.exceeded do |delay|
        worker.class.perform_in(delay, *msg['args'])
      end

      rate_limit.execute
    end

  end # Throttler
end # Sidekiq
