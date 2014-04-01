class LolzWorker2
  include Sidekiq::Worker

  # immediately requeue
  sidekiq_options throttle: { threshold: 10, period: 1.minute, exceeded: ->(delay) { worker.class.perform_async(payload) } }

  def perform(name)
    puts "LolzWorker2!!!"
    puts "OHAI #{name.upcase}!"
  end
end