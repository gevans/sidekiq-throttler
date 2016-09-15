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

      # We now allow for explicitly setting the exceeded behavior.
      # By default (or with a :retry value), the exceeded behavior follows the
      # previous behavior and retries the job.
      #
      # Otherwise, it attempts to use the behavior specified in the class options
      # The specified behavior should be a a proc that takes up to 4 arguments:
      # 1: the period of the rate limiter
      # 2: the worker for the job
      # 3: the message payload
      # 4: the queue the job was pulled from
      # NB: The exceeded behavior passed *MUST* be a proc if you are using less
      # then 4 arguments. Because the rate limiter itself always passes four
      # arguments it doesn't work with a lambda.
       
      worker_options = (worker.class.get_sidekiq_options['throttle'] || {}).stringify_keys

      if worker_options['exceeded'].nil? || worker_options['exceeded'] == :retry
        rate_limit.exceeded do |delay|
          worker.class.perform_in(delay, *msg['args'])
        end
      else
        rate_limit.exceeded &worker_options['exceeded']
      end

      rate_limit.execute
    end

  end # Throttler
end # Sidekiq
