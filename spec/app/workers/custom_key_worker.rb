class CustomKeyWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: 10, period: 1.minute, key: 'winning' }

  def perform(name)
    puts "#{name} is winning!"
  end
end