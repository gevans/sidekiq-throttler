module Sidekiq
  class Throttler
    ##
    # Handles re-scheduling a job for later if it cannot be scheduled right
    # now.
    class TryAgain

      ##
      # Re-schedule the job unless the worker has opted out of rescheduling
      # throttled jobs.
      #
      # @param [Sidekiq::Worker] worker
      #   The worker to rate limit.
      #
      # @param [Array<Object>] args
      #   The arguments with which to schedule the worker.
      #
      # @param [Integer] delay
      #   Delay in seconds to requeue job for.
      #
      # @return [true, false]
      #   Whether or not the job was scheduled.
      def self.reschedule(worker, args, delay)
        should_reschedule = options(worker).fetch('reschedule', true)

        if should_reschedule
          worker.class.perform_in(delay, *args)
          true
        else
          false
        end
      end

      ##
      # Returns the rate limit options for the current running worker.
      #
      # @param [Sidekiq::Worker] worker
      #   The worker to rate limit.
      #
      # @return [{String => Float, Integer}]
      def self.options(worker)
        (worker.class.get_sidekiq_options['throttle'] || {}).stringify_keys
      end

      private_class_method :options
    end # TryAgain
  end # Throttler
end # Sidekiq
