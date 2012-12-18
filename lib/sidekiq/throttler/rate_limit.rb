module Sidekiq
  class Throttler
    ##
    # Handles the tracking of rate limits.
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
      # @param [Array<Object>] payload
      #   The message payload for the current job.
      #
      # @param [String] queue
      #   The queue to rate limit.
      def initialize(worker, payload, queue)
        @worker = worker
        @payload = payload
        @queue = queue
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
        @threshold ||= options['threshold'].to_i
      end

      ##
      # @return [Float]
      #   The number of seconds in the rate limit period.
      def period
        @period ||= options['period'].to_f
      end

      ##
      # Reset throttle counter at the beginning of the next period.
      #
      # @return [true, false]
      def reset?
        @reset ||= options['reset'] || options['reset'].nil?
      end

      ##
      # Get end time of a throttling period.
      #
      # @param [Time] time
      #
      # @return [Time]
      #   The end time of the throttling period.
      def end_of_period(time = Time.now)
        period_end = if reset?
          period * ((time + period).to_f / period).floor
        else
          time + period
        end

        Time.at period_end
      end

      ##
      # @return [Symbol]
      #   The key name used when storing counters for jobs.
      def key
        @key ||= if options['key']
          options['key'].respond_to?(:call) ? options['key'].call(*payload) : options['key']
        else
          "#{@worker.class.to_s.underscore.gsub('/', ':')}:#{@queue}"
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
          @exceeded.call(end_of_period)
        else
          increment
          @within_bounds.call
        end
      end

      ##
      # Reset the tracking of job executions.
      def self.reset!
        @executions = Hash.new { |hash, key| hash[key] = [] }
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
        Thread.exclusive do
          prune(limiter)
          executions[limiter.key].length
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
        Thread.exclusive do
          executions[limiter.key] << Time.now
        end
        count(limiter)
      end

      ##
      # A hash storing job executions as timestamps for each throttled worker.
      def self.executions
        @executions || reset!
      end

      ##
      # Remove old entries for the provided `RateLimit`.
      #
      # @param [RateLimit] limiter
      #   The rate limit to prune.
      def self.prune(limiter)
        executions[limiter.key].select! do |execution|
          limiter.end_of_period(execution) > Time.now
        end
      end

    end # RateLimit
  end # Throttler
end # Sidekiq
