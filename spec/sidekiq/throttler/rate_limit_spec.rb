require 'spec_helper'

shared_examples "incrementing" do
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

      expect(rate_limit.count).to eq(5)
    end
  end
end

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

  before(:each) do
    rate_limit.reset!
  end

  describe '.new' do

    it 'initializes with a provided worker' do
      expect(rate_limit.worker).to eq(worker)
    end

    it 'initializes with provided payload' do
      expect(rate_limit.payload).to eq(payload)
    end

    it 'initializes with a provided queue' do
      expect(rate_limit.queue).to eq('meow')
    end

    context "with an invalid storage backend" do
      it "raises an ArgumentError" do
        expect {
          described_class.new(worker, payload, 'meow', storage: :blarg)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#options' do

    it 'retrieves throttle options from the worker' do
      expect(worker_class.get_sidekiq_options).to receive(:[]).with('throttle')
      rate_limit.options
    end

    it 'stringifies the option keys' do
      expect(worker_class.get_sidekiq_options['throttle']).to receive(:stringify_keys)
      rate_limit.options
    end

    it 'caches the returned options' do
      expect(rate_limit.options.object_id).to eq(rate_limit.options.object_id)
    end

    context 'when the worker specifies no throttle options' do

      let(:worker_class) do
        Class.new do
          include Sidekiq::Worker
        end
      end

      it 'returns an empty hash' do
        expect(rate_limit.options).to eq({})
      end
    end
  end

  describe '#threshold' do

    context 'when threshold is a Proc' do
      let(:worker_class) do
        ProcThresholdWorker
      end

      let(:payload) do
        [1, 500]
      end

      it 'returns the result of the called Proc' do
        expect(rate_limit.threshold).to eq(500)
      end
    end

    it 'retrieves the threshold from #options' do
      rate_limit.options['threshold'] = 26
      expect(rate_limit.threshold).to eq(26)
    end

    it 'converts the threshold to an integer' do
      rate_limit.options['threshold'] = '33'
      expect(rate_limit.threshold).to be_a(Integer)
    end

    it 'caches the returned integer' do
      expect(rate_limit.threshold.object_id).to eq(rate_limit.threshold.object_id)
    end
  end

  describe '#period' do

    context 'when period is a Proc' do
      let(:worker_class) do
        ProcPeriodWorker
      end

      let(:payload) do
        [1, 1.minute]
      end

      it 'returns the result of the called Proc' do
        expect(rate_limit.period).to eq(60)
      end
    end

    it 'retrieves the period from #options' do
      rate_limit.options['period'] = 10.0
      expect(rate_limit.period).to eq(10.0)
    end

    it 'converts the period to a float' do
      rate_limit.options['period'] = 27
      expect(rate_limit.period).to be_a(Float)
    end

    it 'caches the returned float' do
      expect(rate_limit.period.object_id).to eq(rate_limit.period.object_id)
    end
  end

  describe '#key' do

    let(:worker_class) do
      CustomKeyWorker
    end

    it 'caches the key from the worker' do
      expect(rate_limit.key.object_id).to eq(rate_limit.key.object_id)
    end

    context 'when key is a string' do

      it 'returns the key as a symbol' do
        expect(rate_limit.key).to eq('winning')
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
        expect(rate_limit.key).to eq('wat:is:this')
      end
    end
  end

  describe '#can_throttle?' do

    context 'when options are correctly specified' do

      it 'returns true' do
        expect(rate_limit.can_throttle?).to be_truthy
      end
    end

    %w(threshold period).each do |method|

      context "when ##{method} is zero" do

        it 'returns false' do
          allow(rate_limit).to receive(method.to_sym).and_return(0)
          expect(rate_limit.can_throttle?).to be_falsey
        end
      end
    end
  end

  describe '#exceeded?' do

    context 'when #count is equal to #threshold' do

      it 'returns true' do
        expect(rate_limit).to receive(:count).and_return(rate_limit.threshold)
        expect(rate_limit).to be_exceeded
      end
    end

    context 'when #count is greater than #threshold' do

      it 'returns true' do
        expect(rate_limit).to receive(:count).and_return(rate_limit.threshold + 1)
        expect(rate_limit).to be_exceeded
      end
    end

    context 'when #count is less than #threshold' do

      it 'returns false' do
        expect(rate_limit).to receive(:count).and_return(0)
        expect(rate_limit).not_to be_exceeded
      end
    end
  end

  describe '#within_bounds?' do

    it 'returns the opposite of #exceeded?' do
      expect(rate_limit).to receive(:exceeded?).and_return(true)
      expect(rate_limit).not_to be_within_bounds
      expect(rate_limit).to receive(:exceeded?).and_return(false)
      expect(rate_limit).to be_within_bounds
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
        expect(rate_limit).to receive(:can_throttle?).and_return(false)
      end

      it 'calls the within bounds callback' do
        callback = Proc.new {}
        expect(callback).to receive(:call)

        rate_limit.within_bounds(&callback)
        rate_limit.execute
      end

      it 'does not increment the counter' do
        rate_limit.within_bounds {}

        expect(rate_limit).not_to receive(:increment)
        rate_limit.execute
      end
    end

    context 'when rate limit is exceeded' do

      before do
        expect(rate_limit).to receive(:exceeded?).and_return(true)
      end

      it 'calls the exceeded callback with the configured #period' do
        callback = Proc.new {}
        expect(callback).to receive(:call).with(rate_limit.period)

        rate_limit.exceeded(&callback)
        rate_limit.execute
      end
    end

    context 'when rate limit is within bounds' do

      it 'increments the counter' do
        rate_limit.within_bounds {}

        expect(rate_limit).to receive(:increment)
        rate_limit.execute
      end

      it 'calls the within bounds callback' do
        callback = Proc.new {}
        expect(callback).to receive(:call)

        rate_limit.within_bounds(&callback)
        rate_limit.execute
      end
    end
  end

  describe '#count' do

    context 'when no jobs have executed' do

      it 'returns 0' do
        expect(rate_limit.count).to be_zero
      end
    end
  end

  describe '#increment' do
    include_examples "incrementing"
  end

  context "with a :redis storage backend" do
    subject(:rate_limit) do
      described_class.new(worker, payload, 'meow', storage: :redis)
    end

    include_examples "incrementing"
  end
end
