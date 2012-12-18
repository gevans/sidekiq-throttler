require 'spec_helper'

describe Sidekiq::Throttler do

  subject(:throttler) do
    described_class.new
  end

  let(:worker) do
    LolzWorker.new
  end

  let(:message) do
    {
      args: 'Clint Eastwood'
    }
  end

  let(:queue) do
    'default'
  end

  describe '#call' do

    it 'instantiates a rate limit with the worker, args, and queue' do
      rate_limit = Sidekiq::Throttler::RateLimit.new(worker, message['args'], queue)
      Sidekiq::Throttler::RateLimit.should_receive(:new).with(
        worker, message['args'], queue
      ).and_return(rate_limit)

      throttler.call(worker, message, queue) {}
    end

    it 'yields in RateLimit#within_bounds' do
      expect { |b| throttler.call(worker, message, queue, &b) }.to yield_with_no_args
    end

    it 'calls RateLimit#execute' do
      Sidekiq::Throttler::RateLimit.any_instance.should_receive(:execute)
      throttler.call(worker, message, queue)
    end

    context 'when rate limit is exceeded' do

      it 'requeues the job with a delay' do
        Sidekiq::Throttler::RateLimit.any_instance.should_receive(:exceeded?).and_return(true)
        Sidekiq::Throttler::RateLimit.any_instance.should_receive(:end_of_period).and_return(:new_time)
        worker.class.should_receive(:perform_at).with(:new_time, *message['args'])
        throttler.call(worker, message, queue)
      end
    end
  end
end
