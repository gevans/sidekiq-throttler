class LolzWorker2
  include Sidekiq::Worker

  # immediately requeue
  sidekiq_options throttle: { threshold: 10, period: 1.minute, exceeded: Proc.new {|delay| worker.class.perform_async(payload) } }
  # , when_exceeded:  ->(delay, worker, payload, queue) { puts "HURFFF"; puts "payload: #{payload}" } 
  # { @worker.class.perform_async(@payload); puts "wtf2wtf2" }

  def perform(name)
    puts "LolzWorker2!!!"
    puts "OHAI #{name.upcase}!"
  end
end