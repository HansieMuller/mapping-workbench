require "uri"
url = ENV.fetch("MW_REDIS_URL", "redis://127.0.0.1:6387/0")
uri = URI.parse(url)
raise "Redis must bind locally" unless %w[127.0.0.1 localhost ::1].include?(uri.host)
Sidekiq.configure_server { |config| config.redis = { url: url } }
Sidekiq.configure_client { |config| config.redis = { url: url } }
