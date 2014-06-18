## 0.4.1 (June 18, 2014)

* Dependency lock is loosened further for compatibility with Sidekiq 3.x.

  *Gabe Evans*

* Appraisal is used for continous integration with Sidekiq 2.x and Sidekiq's
  master branch.

  *Gabe Evans*

* Specs now use RSpec 3 and the `expect()` syntax.

  *Gabe Evans*

## 0.4.0 (April 24, 2014)

* Now supports using a Proc for `:period` option.

  *Kainage*

* Fix for throttler spec that was using symbol keys but the testing with
  string keys.

  *worst*

* Dependency lock is loosened for compatibility with Sidekiq 3.0.

  *Gabe Evans*

## 0.3.1 (November 5, 2013)

* `Singleton` is explicitly required, fixing a `NameError`.

  *Bruno Pinto*

## 0.3.0 (October 3, 2013)

* Redis is supported as a storage backend for persistence of job execution
  counters across multiple Sidekiq processes.

  *Louis Simoneau*

* Only Active Support's `Time` extensions are required. Fixes compatibility with
  Rails 4.

  *Louis Simoneau*

## 0.2.0 (June 29, 2013)

* Now supports using a Proc for `:threshold` argument, similar to how the
  `:key` argument works.

  *Kyle Dayton*

## 0.1.0 (December 13, 2012)

* Initial release.

  *Gabe Evans*
