class ProcThresholdWorker
  include Sidekiq::Worker

  sidekiq_options throttle: { threshold: Proc.new { |user_id, limit| limit }, period: 1.minute }

  def perform(user_id, limit)
    puts user_id
    puts limit
  end
end