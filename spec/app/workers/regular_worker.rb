class RegularWorker
  include Sidekiq::Worker

  def perform(name)
    puts "..."
  end
end