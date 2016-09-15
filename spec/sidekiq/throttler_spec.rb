require 'spec_helper'

describe Sidekiq::Throttler do

  subject(:throttler) do
    described_class.new(options)
  end

  let(:worker) do
    LolzWorker.new
  end

  let(:worker2) do
    LolzWorker2.new
  end

  let(:options) do
    { storage: :memory }
  end

  let(:message) do
    {
      'args' => 'Clint Eastwood'
    }
  end

  let(:queue) do
    'default'
  end

  describe '#call' do

    it 'instantiates a rate limit with the worker, args, and queue' do
      expect(Sidekiq::Throttler::RateLimit).to receive(:new).with(
        worker, message['args'], queue, options
      ).and_call_original

      throttler.call(worker, message, queue) {}
    end

    it 'yields in RateLimit#within_bounds' do
      expect { |b| throttler.call(worker, message, queue, &b) }.to yield_with_no_args
    end

    it 'calls RateLimit#execute' do
      expect_any_instance_of(Sidekiq::Throttler::RateLimit).to receive(:execute)
      throttler.call(worker, message, queue)
    end

    context 'when rate limit is exceeded' do

      it 'requeues the job with a delay' do
        expect_any_instance_of(Sidekiq::Throttler::RateLimit).to receive(:exceeded?).and_return(true)
        expect(worker.class).to receive(:perform_in).with(1.minute, *message['args'])
        throttler.call(worker, message, queue)
      end

      it 'properly performs the behavior specificed in exceeded option' do
        Sidekiq::Throttler::RateLimit.any_instance.should_receive(:exceeded?).and_return(true)
        worker2.class.should_receive(:perform_async).with(*message['args'])
        throttler.call(worker2, message, queue)
      end
    end
  end
end
