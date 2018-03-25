require 'bundler/setup'

require 'dotenv'
Dotenv.load File.expand_path('../config/.env', __FILE__)

require 'sidekiq'
Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"}
end
Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}" }
end

require 'sidekiq/api'
queue = Sidekiq::Queue.new
retryset = Sidekiq::RetrySet.new
deadset = Sidekiq::DeadSet.new
processset = Sidekiq::ProcessSet.new
workers = Sidekiq::Workers.new
puts "queue size: #{queue.size}"
puts "retryset size: #{retryset.size}"
puts "deadset size: #{deadset.size}"
puts "processset size: #{processset.size}"
puts "workers size: #{workers.size}"