class LolzWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: 10, period: 1.minute }

  def perform(name)
    puts "OHAI #{name.upcase}!"
  end
end