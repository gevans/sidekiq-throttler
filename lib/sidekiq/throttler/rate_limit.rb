module Sidekiq
  class Throttler
    ##
    # Handles the tracking of rate limits. Based on
    # [ratelimit](https://github.com/ejfinneran/ratelimit/blob/master/lib/ratelimit.rb)
    # with the addition of using `Thread.exclusive` when accessing Redis.
    #
    # Rate limits are stored and incremented in "buckets" which represent a
    # short period of time (by default, 10 minutes) split into intervals (by
    # default, 5 seconds). Each bucket expires after a short period of time,
    # lowering the {#count} on the rate limit.
    #
    # TODO: Consider reducing `threshold` and `period` to smooth out job
    # executions so that "24 jobs every 1 hour" becomes "1 job every 2 minutes
    # and 30 seconds"
    class RateLimit

      ##
      # @return [Sidekiq::Worker]
      #   The worker to rate limit.
      attr_reader :worker

      ##
      # @return [Array]
      #   The message payload for the current job.
      attr_reader :payload

      ##
      # @return [String]
      #   The queue to rate limit.
      attr_reader :queue

      ##
      # @param [Sidekiq::Worker] worker
      #   The worker to rate limit.
      #
      # @param [String] queue
      #   The queue to rate limit.
      def initialize(worker, payload, queue)
        @worker = worker
        @payload = payload
        @queue = queue
      end

      def count
        self.class.count(self)
      end

      def increment
        self.class.increment(self)
      end

      ##
      # Returns the rate limit options for the current running worker.
      #
      # @return [{String => Float, Integer}]
      def options
        @options ||= (worker.class.get_sidekiq_options['throttle'] || {}).stringify_keys
      end

      ##
      # @return [Integer]
      #   The number of jobs that are allowed within the `period`.
      def threshold
        @threshold ||= options['threshold'].to_i
      end

      ##
      # @return [Float]
      #   The number of seconds in the rate limit period.
      def period
        @period ||= options['period'].to_f
      end

      ##
      # @return [Symbol]
      #   The key name used when storing counters for jobs.
      def key
        @key ||= if options['key']
          options['key'].respond_to?(:call) ? options['key'].call(*payload) : options['key']
        else
          "#{@worker.class.to_s.underscore.gsub('/', '_')}_#{@queue}"
        end.to_sym
      end

      ##
      # Checks if rate limiting options were correctly specified on the worker.
      #
      # @return [true, false]
      def can_throttle?
        [threshold, period].select(&:zero?).empty?
      end

      def self.reset!
        Thread.exclusive do
          @executions = Hash.new { |hash, key| hash[key] = [] }
        end
      end

      private

      def self.count(limiter)
        Thread.exclusive do
          prune(limiter)
          executions[limiter.key].length
        end
      end

      def self.increment(limiter)
        Thread.exclusive do
          executions[limiter.key] << Time.now
          prune(limiter)
        end
        limiter
      end

      def self.executions
        @executions || reset!
      end

      def self.prune(limiter)
        executions[limiter.key].select! do |execution|
          (Time.now - execution) < limiter.period
        end
      end

    end # RateLimit
  end # Throttler
end # Sidekiq