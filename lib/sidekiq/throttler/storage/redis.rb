module Sidekiq
  class Throttler
    module Storage
      ##
      # Stores job executions in Redis lists 
      class Redis
        include Singleton

        ##
        # Number of executions for +key+.
        #
        # @param [String]
        #   Key to fetch count for
        #
        # @return [Fixnum]
        #   Execution count
        def count(key)
          Sidekiq.redis do |conn|
            conn.llen(namespace_key(key))
          end
        end

        ##
        # Remove entries older than +cutoff+.
        #
        # @param [String] key
        #   The key to prune
        #
        # @param [Time] cutoff
        #   Oldest allowable time
        def prune(key, cutoff)
          Sidekiq.redis do |conn|
            prune_one = ->(timestamp) {
              if timestamp && timestamp.to_i <= cutoff.to_i
                last = conn.rpop(namespace_key(key))
                if last == timestamp
                  true
                else
                  conn.rpush(namespace_key(key), last)
                  nil
                end
              end
            }

            loop while prune_one.call(conn.lindex(namespace_key(key), -1))
          end
        end

        ##
        # Add a new entry to the hash
        #
        # @param [String] key
        #   The key to append to
        #
        # @param [Time]
        #   The time to insert
        def append(key, time)
          Sidekiq.redis do |conn|
            conn.lpush(namespace_key(key), time.to_i)
          end
        end

        def reset
          Sidekiq.redis do |conn|
            conn.keys(namespace_key("*")).each do |key|
              conn.del(key)
            end
          end
        end

        private

        def namespace_key(key)
          "throttled:#{key}"
        end
      end
    end # Storage
  end # Throttler
end # Sidekiq
