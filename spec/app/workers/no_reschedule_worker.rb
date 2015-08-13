class NoRescheduleWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: 10, period: 1.minute, reschedule: false }

  def perform(name); end
end
