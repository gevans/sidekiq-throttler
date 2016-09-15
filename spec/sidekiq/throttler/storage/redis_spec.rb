require "spec_helper"

describe Sidekiq::Throttler::Storage::Redis do
  let(:storage) { described_class.instance }

  before(:each) do
    @sidekiq = double()
    allow(Sidekiq).to receive(:redis).and_yield(@sidekiq)
  end

  describe "#prune" do
    it "pops the last item off the list if it's lower than the cutoff" do
      allow(@sidekiq).to receive(:lindex).and_return(100, nil)
      expect(@sidekiq).to receive(:rpop).with("throttled:fake").and_return(100)
      storage.prune("fake", 200)
    end

    it "leaves the last item on the list if it's higher than the cutoff" do
      allow(@sidekiq).to receive(:lindex).and_return(200, nil)
      expect(@sidekiq).not_to receive(:rpop)
      storage.prune("fake", 100)
    end

    context "when another job has concurrently removed a timestamp" do

      before(:each) do
        allow(@sidekiq).to receive(:lindex) { 100 }
        allow(@sidekiq).to receive(:rpop)   { 200 }
      end

      it "pushes the value back onto the list" do
        expect(@sidekiq).to receive(:rpush).with("throttled:fake", 200)
        storage.prune("fake", 1000)
      end
    end
  end
end
