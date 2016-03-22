require 'sidekiq'
require 'active_support/core_ext/numeric/time'
require 'singleton'

require 'sidekiq/throttler/version'
require 'sidekiq/throttler/rate_limit'

require 'sidekiq/throttler/storage/memory'
require 'sidekiq/throttler/storage/redis'

module Sidekiq
  ##
  # Sidekiq server middleware. Throttles jobs when they exceed limits specified
  # on the worker. Jobs that exceed the limit are requeued with a delay.
  class Throttler
    def initialize(options = {})
      @options = options.dup
    end

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
      rate_limit = RateLimit.new(worker, msg['args'], queue, @options)

      rate_limit.within_bounds do
        yield
      end

      rate_limit.exceeded do |delay|
        within_batch(msg) do |args|
          worker.class.perform_in(delay, args)
        end
      end

      rate_limit.execute
    end

    private

    # Support Siekiq::Pro batches
    # Requeue within a batch if bid is present
    def within_batch(msg)
      args, bid = msg['args'], msg['bid']
      
      if bid && defined?(Sidekiq::Batch)
        batch = Sidekiq::Batch.new(bid)
        batch.jobs { yield args } 
      else
        yield args
      end
    end
  end # Throttler
end # Sidekiq
