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

      it 'returns the key as a symbol' do
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

  describe '#can_throttle?' do

    context 'when options are correctly specified' do

      it 'returns true' do
        rate_limit.can_throttle?.should be_true
      end
    end

    %w(threshold period).each do |method|

      context "when ##{method} is zero" do

        it 'returns false' do
          rate_limit.stub(method.to_sym).and_return(0)
          rate_limit.can_throttle?.should be_false
        end
      end
    end
  end

  describe '#exceeded?' do

    context 'when #count is equal to #threshold' do

      it 'returns true' do
        rate_limit.should_receive(:count).and_return(rate_limit.threshold)
        rate_limit.should be_exceeded
      end
    end

    context 'when #count is greater than #threshold' do

      it 'returns true' do
        rate_limit.should_receive(:count).and_return(rate_limit.threshold + 1)
        rate_limit.should be_exceeded
      end
    end

    context 'when #count is less than #threshold' do

      it 'returns false' do
        rate_limit.should_receive(:count).and_return(0)
        rate_limit.should_not be_exceeded
      end
    end
  end

  describe '#within_bounds?' do

    it 'returns the opposite of #exceeded?' do
      rate_limit.should_receive(:exceeded?).and_return(true)
      rate_limit.should_not be_within_bounds
      rate_limit.should_receive(:exceeded?).and_return(false)
      rate_limit.should be_within_bounds
    end
  end

  describe '#exceeded' do

    it 'accepts a block as a callback' do
      rate_limit.exceeded { 'rawr' }
    end
  end

  describe '#within_bounds' do

    it 'accepts a block as a callback' do
      rate_limit.within_bounds { 'grr' }
    end
  end

  describe '#execute' do

    context 'when rate limit cannot be throttled' do

      before do
        rate_limit.should_receive(:can_throttle?).and_return(false)
      end

      it 'calls the within bounds callback' do
        callback = Proc.new {}
        callback.should_receive(:call)

        rate_limit.within_bounds(&callback)
        rate_limit.execute
      end

      it 'does not increment the counter' do
        rate_limit.within_bounds {}

        rate_limit.should_not_receive(:increment)
        rate_limit.execute
      end
    end

    context 'when rate limit is exceeded' do

      before do
        rate_limit.should_receive(:exceeded?).and_return(true)
      end

      it 'calls the exceeded callback with the configured #period' do
        callback = Proc.new {}
        callback.should_receive(:call).with(rate_limit.period)

        rate_limit.exceeded(&callback)
        rate_limit.execute
      end
    end

    context 'when rate limit is within bounds' do

      it 'increments the counter' do
        rate_limit.within_bounds {}

        rate_limit.should_receive(:increment)
        rate_limit.execute
      end

      it 'calls the within bounds callback' do
        callback = Proc.new {}
        callback.should_receive(:call)

        rate_limit.within_bounds(&callback)
        rate_limit.execute
      end
    end
  end

  describe '#count' do

    context 'when no jobs have executed' do

      it 'returns 0' do
        rate_limit.count.should be_zero
      end
    end
  end

  describe '#increment' do

    it 'increments #count by one' do
      Timecop.freeze do
        expect { rate_limit.increment }.to change{ rate_limit.count }.by(1)
      end
    end

    context 'when #period has passed' do

      it 'removes old increments' do
        rate_limit.options['period'] = 5

        Timecop.freeze

        20.times do
          Timecop.travel(1.second.from_now)
          rate_limit.increment
        end

        rate_limit.count.should eq(5)
      end
    end
  end
end