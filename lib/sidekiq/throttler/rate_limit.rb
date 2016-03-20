require 'thread'

module Sidekiq
  class Throttler
    ##
    # Handles the tracking of rate limits.
    #
    # TODO: Consider reducing `threshold` and `period` to smooth out job
    # executions so that "24 jobs every 1 hour" becomes "1 job every 2 minutes
    # and 30 seconds"
    class RateLimit

      LOCK = Mutex.new

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
      # @param [Array<Object>] payload
      #   The message payload for the current job.
      #
      # @param [String] queue
      #   The queue to rate limit.
      #
      # @option [Symbol] :storage
      #   Either :memory or :redis, the storage backend to use
      def initialize(worker, payload, queue, options = {})
        @worker = worker
        @payload = payload
        @queue = queue

        unless @storage_class = lookup_storage(options.fetch(:storage, :memory))
          raise ArgumentError,
            "Unrecognized storage backend: #{options[:storage].inspect}"
        end
      end

      ##
      # Fetch the number of jobs executed.
      #
      # @return [Integer]
      #   The current number of jobs executed.
      def count
        self.class.count(self)
      end

      ##
      # Increment the count of jobs executed.
      #
      # @return [Integer]
      #   The current number of jobs executed.
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
        @threshold ||= (options['threshold'].respond_to?(:call) ? options['threshold'].call(*payload) : options['threshold']).to_i
      end

      ##
      # @return [Float]
      #   The number of seconds in the rate limit period.
      def period
        @period ||= (options['period'].respond_to?(:call) ? options['period'].call(*payload) : options['period']).to_f
      end

      ##
      # @return [String]
      #   The key name used when storing counters for jobs.
      def key
        @key ||= if options['key']
          options['key'].respond_to?(:call) ? options['key'].call(*payload) : options['key']
        else
          base_key = "#{@worker.class.to_s.underscore.gsub('/', ':')}:#{@queue}"
          if options['unique_args']
            "#{base_key}:#{payload.join('/')}"
          else
            base_key
          end
        end
      end

      ##
      # Check if rate limiting options were correctly specified on the worker.
      #
      # @return [true, false]
      def can_throttle?
        [threshold, period].select(&:zero?).empty?
      end

      ##
      # Check if rate limit has exceeded the threshold.
      #
      # @return [true, false]
      def exceeded?
        count >= threshold
      end

      # Check if the same worker with args is already in the queue
      def scheduled?
        if options['scheduled_unique']
          Sidekiq::ScheduledSet.new.select{ |job| job.klass == worker.class.to_s &&  job.args == payload}.any?
        else
          false
        end
      end

      ##
      # Check if rate limit is within the threshold.
      #
      # @return [true, false]
      def within_bounds?
        !exceeded?
      end

      ##
      # Set a callback to be executed when {#execute} is called and the rate
      # limit has not exceeded the threshold.
      def within_bounds(&block)
        @within_bounds = block
      end

      ##
      # Set a callback to be executed when {#execute} is called and the rate
      # limit has exceeded the threshold.
      #
      # @yieldparam [Integer] delay
      #   Delay in seconds to requeue job for.
      def exceeded(&block)
        @exceeded = block
      end

      ##
      # Executes a callback ({#within_bounds}, or {#exceeded}) depending on the
      # state of the rate limit.
      def execute
        return @within_bounds.call unless can_throttle?

        if exceeded?
          @exceeded.call(period)
        else
          increment
          @within_bounds.call
        end
      end

      ##
      # Reset the tracking of job executions.
      def reset!
        executions.reset
      end

      ##
      # Get the storage backend.
      def executions
        @storage_class.instance
      end

      private

      ##
      # Fetch the number of jobs executed by the provided `RateLimit`.
      #
      # @param [RateLimit] limiter
      #
      # @return [Integer]
      #   The current number of jobs executed.
      def self.count(limiter)
        LOCK.synchronize do
          prune(limiter)
          limiter.executions.count(limiter.key)
        end
      end

      ##
      # Increment the count of jobs executed by the provided `RateLimit`.
      #
      # @param [RateLimit] limiter
      #
      # @return [Integer]
      #   The current number of jobs executed.
      def self.increment(limiter)
        LOCK.synchronize do
          limiter.executions.append(limiter.key, Time.now)
        end
        count(limiter)
      end

      ##
      # Remove old entries for the provided `RateLimit`.
      #
      # @param [RateLimit] limiter
      #   The rate limit to prune.
      def self.prune(limiter)
        limiter.executions.prune(limiter.key, Time.now - limiter.period)
      end

      ##
      # Lookup storage class for a given options key
      #
      # @param [Symbol] key
      #   The options key, :memory or :redis
      #
      # @return [Class]
      #   The storage backend class, or nil if the key is not found
      def lookup_storage(key)
        { memory: Storage::Memory, redis: Storage::Redis }[key]
      end
    end # RateLimit
  end # Throttler
end # Sidekiq
