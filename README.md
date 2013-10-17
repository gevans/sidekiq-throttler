# Sidekiq::Throttler

[![Build Status](https://secure.travis-ci.org/gevans/sidekiq-throttler.png)](http://travis-ci.org/gevans/sidekiq-throttler)
[![Dependency Status](https://gemnasium.com/gevans/sidekiq-throttler.png)](https://gemnasium.com/gevans/sidekiq-throttler)

Sidekiq::Throttler is a middleware for Sidekiq that adds the ability to rate
limit job execution on a per-worker basis.

## Compatibility

Sidekiq::Throttler is actively tested against MRI versions 2.0.0 and 1.9.3.

## Installation

Add this line to your application's Gemfile:

    gem 'sidekiq-throttler'

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

## Usage

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

If throttling is per-user, for example, you can specify a `Proc` for `key` which
accepts the arguments passed to your worker's `perform` method:

```ruby
sidekiq_options throttle: { threshold: 20, period: 1.day, key: ->(user_id){ user_id } }
```

In the above example, jobs are throttled for each user when they exceed 20 in a
day.

Thresholds can be configured based on the arguments passed to your worker's `perform` method,
similar to how the `key` option works:

```ruby
sidekiq_options throttle: { threshold: ->(user_id, rate_limit) { rate_limit }, period: 1.hour, key: ->(user_id, rate_limit){ user_id } }
```

In the above example, jobs are throttled for each user when they exceed the rate limit provided in the message. This is useful in cases where each user may have a different rate limit (ex: interacting with external APIs)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT Licensed. See LICENSE.txt for details.
