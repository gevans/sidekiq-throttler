require 'spec_helper'

describe Sidekiq::Throttler::RateLimit do

  let(:worker_class) do
    LolzWorker
  end

  let(:worker) do
    worker_class.new
  end

  let(:payload) do
    ['world']
  end

  let(:queue) do
    'meow'
  end

  subject(:rate_limit) do
    described_class.new(worker, payload, 'meow')
  end

  describe '.new' do

    it 'initializes with a provided worker' do
      rate_limit.worker.should eq(worker)
    end

    it 'initializes with provided payload' do
      rate_limit.payload.should eq(payload)
    end

    it 'initializes with a provided queue' do
      rate_limit.queue.should eq('meow')
    end
  end

  describe '#inspect' do

    it 'returns a string combining #to_s with the class name' do
      rate_limit.inspect.should eq('#<Sidekiq::Throttler::RateLimit throttle:lolz_worker:meow>')
    end
  end

  describe '#to_s' do

    it 'returns a string representing a rate limit key' do
      rate_limit.to_s.should eq('throttle:lolz_worker:meow')
    end

    it 'caches the returned string' do
      rate_limit.to_s.object_id.should eq(rate_limit.to_s.object_id)
    end

    context 'when a key is configured' do

      context 'when key is a string' do

        let(:worker_class) do
          CustomKeyWorker
        end

        it 'returns the key' do
          rate_limit.to_s.should eq('throttle:winning')
        end
      end

      context 'when key is a Proc' do

        let(:worker_class) do
          ProcWorker
        end

        let(:payload) do
          ['baz', 'bar', 'blitz']
        end

        it 'returns the result of the Proc prefixed by throttle:' do
          rate_limit.to_s.should eq('throttle:baz:bar:blitz')
        end
      end
    end
  end

  describe '#options' do

    it 'retrieves throttle options from the worker' do
      worker_class.get_sidekiq_options.should_receive(:[]).with('throttle')
      rate_limit.options
    end

    it 'stringifies the option keys' do
      worker_class.get_sidekiq_options['throttle'].should_receive(:stringify_keys)
      rate_limit.options
    end

    it 'caches the returned options' do
      rate_limit.options.object_id.should eq(rate_limit.options.object_id)
    end

    context 'when the worker specifies no throttle options' do

      let(:worker_class) do
        Class.new do
          include Sidekiq::Worker
        end
      end

      it 'returns an empty hash' do
        rate_limit.options.should eq({})
      end
    end
  end

  describe '#threshold' do

    it 'retrieves the threshold from #options' do
      rate_limit.options['threshold'] = 26
      rate_limit.threshold.should eq(26)
    end

    it 'converts the threshold to an integer' do
      rate_limit.options['threshold'] = '33'
      rate_limit.threshold.should be_a(Integer)
    end

    it 'caches the returned integer' do
      rate_limit.threshold.object_id.should eq(rate_limit.threshold.object_id)
    end
  end

  describe '#period' do

    it 'retrieves the period from #options' do
      rate_limit.options['period'] = 10.0
      rate_limit.period.should eq(10.0)
    end

    it 'converts the period to a float' do
      rate_limit.options['period'] = 27
      rate_limit.period.should be_a(Float)
    end

    it 'caches the returned float' do
      rate_limit.period.object_id.should eq(rate_limit.period.object_id)
    end
  end

  describe '#key' do

    let(:worker_class) do
      CustomKeyWorker
    end

    it 'caches the key from the worker' do
      rate_limit.key.object_id.should eq(rate_limit.key.object_id)
    end

    context 'when key is a string' do

      it 'returns the key' do
        rate_limit.key.should eq('winning')
      end
    end

    context 'when key is a Proc' do

      let(:worker_class) do
        ProcWorker
      end

      let(:payload) do
        ['wat', 'is', 'this']
      end

      it 'returns the result of the called Proc' do
        rate_limit.key.should eq('wat:is:this')
      end
    end
  end

  describe '#bucket_span' do

    it 'retrieves the bucket_span from #options' do
      rate_limit.options['bucket_span'] = 75
      rate_limit.bucket_span.should eq(75)
    end

    it 'converts the bucket_span to an integer' do
      rate_limit.options['bucket_span'] = 'blah'
      rate_limit.bucket_span.should be_a(Integer)
    end

    it 'caches the returned integer' do
      rate_limit.bucket_span.object_id.should eq(rate_limit.bucket_span.object_id)
    end

    it 'defaults to #period' do
      rate_limit.options['bucket_span'] = nil
      rate_limit.bucket_span.should eq(rate_limit.period)
    end
  end

  describe '#bucket_interval' do

    it 'retrieves the bucket_interval from #options' do
      rate_limit.options['bucket_interval'] = 29
      rate_limit.bucket_interval.should eq(29)
    end

    it 'converts the bucket_interval to an integer' do
      rate_limit.options['bucket_interval'] = 'sadf'
      rate_limit.bucket_interval.should be_a(Integer)
    end

    it 'caches the returned integer' do
      rate_limit.bucket_interval.object_id.should eq(rate_limit.bucket_interval.object_id)
    end

    it 'defaults to 5' do
      rate_limit.options['bucket_interval'] = nil
      rate_limit.bucket_interval.should eq(5)
    end
  end

  describe '#bucket_count' do

    it 'divides the #bucket_span and #bucket_interval and returns the ceiling' do
      rate_limit.options['bucket_span'] = 500
      rate_limit.options['bucket_interval'] = 27
      rate_limit.bucket_count.should eq(19)

      rate_limit.options['bucket_span'] = 345
      rate_limit.options['bucket_interval'] = 12
      rate_limit.instance_variable_set(:@bucket_count, nil)
      rate_limit.instance_variable_set(:@bucket_interval, nil)
      rate_limit.instance_variable_set(:@bucket_span, nil)
      rate_limit.bucket_count.should eq(29)
    end

    it 'caches the returned integer' do
      rate_limit.bucket_count.object_id.should eq(rate_limit.bucket_count.object_id)
    end
  end

  describe '#can_throttle?' do

    context 'when options are correctly specified' do

      it 'returns true' do
        rate_limit.can_throttle?.should be_true
      end
    end

    %w(threshold period bucket_span bucket_interval).each do |method|

      context "when ##{method} is zero" do

        it 'returns false' do
          rate_limit.stub(method.to_sym).and_return(0)
          rate_limit.can_throttle?.should be_false
        end
      end
    end
  end
end