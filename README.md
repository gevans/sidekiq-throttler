# Sidekiq::Throttler

[![Build Status](https://secure.travis-ci.org/gevans/sidekiq-throttler.png)](http://travis-ci.org/gevans/sidekiq-throttler)
[![Dependency Status](https://gemnasium.com/gevans/sidekiq-throttler.png)](https://gemnasium.com/gevans/sidekiq-throttler)
[![Gem Version](https://badge.fury.io/rb/sidekiq-throttler.svg)](http://badge.fury.io/rb/sidekiq-throttler)

Sidekiq::Throttler is a middleware for Sidekiq that adds the ability to rate
limit job execution on a per-worker basis.

## Compatibility

Sidekiq::Throttler supports Sidekiq versions 2 and 3 and is actively tested against Ruby versions 2.0.0, 2.1, and 2.2.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-throttler'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-throttler

## Configuration

In a Rails initializer or wherever you've configured Sidekiq, add
Sidekiq::Throttler to your server middleware:

```ruby
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Throttler
  end
end
```

Sidekiq::Throttler defaults to in-memory storage of job execution times. If
you have multiple worker processes, or frequently restart your processes, this
will be unreliable. Instead, specify the `:redis` storage option:

```ruby
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Throttler, storage: :redis
  end
end
```

## Basic Usage

In a worker, specify a threshold (maximum jobs) and period for throttling:

```ruby
class MyWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: 50, period: 1.hour }

  def perform(user_id)
    # Do some heavy API interactions.
  end
end
```

In the above example, when the number of executed jobs for the worker exceeds
50 in an hour, remaining jobs will be delayed.

## Advanced Usage

### Custom Keys

By default, each worker has its own key for throttling. For example:

```ruby
class FooWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: 50, period: 1.hour }

  # ...
end

class BarWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: 50, period: 1.hour }

  # ...
end
```

Even though `FooWorker` and `BarWorker` use the same throttle options, they are
treated as different groups. To have multiple workers with shared throttling,
the `:key` options can be used:

```ruby
sidekiq_options throttle: { threshold: 50, period: 1.hour, key: 'foobar' }
```

Any jobs using the same key, regardless of the worker will be tracked under the
same conditions.

### Dynamic Throttling

Each option (`:threshold`, `:period`, and `:key`) accepts a static value but can
*also* accept a `Proc` that's called each time a job is processed.

#### Dynamic Keys

If throttling is per-user, for example, you can specify a `Proc` for `key` which
accepts the arguments passed to your worker's `perform` method:

```ruby
sidekiq_options throttle: { threshold: 20, period: 1.day, key: ->(user_id){ user_id } }
```

In the above example, jobs are throttled for each user when they exceed 20 in a
day.

#### Dynamic Thresholds

Thresholds can be configured based on the arguments passed to your worker's `perform` method,
similar to how the `key` option works:

```ruby
sidekiq_options throttle: { threshold: ->(user_id, rate_limit) { rate_limit }, period: 1.hour, key: ->(user_id, rate_limit){ user_id } }
```

In the above example, jobs are throttled for each user when they exceed the rate limit provided in the message. This is useful in cases where each user may have a different rate limit (ex: interacting with external APIs)

#### Dynamic Periods

In this contrived example, our worker is limited to 9 thousand jobs every 10
minutes. However, on Tuesdays limit jobs to 9 thousand every *15 minutes*:

```ruby
sidekiq_options throttle: { threshold: 9000, period: ->{ Date.today.tuesday? ? 15.minutes : 10.minutes } }
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT Licensed. See LICENSE.txt for details.
