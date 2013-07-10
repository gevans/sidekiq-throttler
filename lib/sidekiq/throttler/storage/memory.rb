module Sidekiq
  class Throttler
    module Storage
      class Memory
        def initialize
          @hash = Hash.new { |hash, key| hash[key] = [] }
        end

        def count(key)
          @hash[key].length
        end

        def prune(key, cutoff)
          @hash[key].select! { |time| time > cutoff }
        end

        def append(key, time)
          @hash[key] << time
        end
      end
    end # Storage
  end # Throttler
end # Sidekiq
