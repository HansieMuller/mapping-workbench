# Avoid Rails silently merging an unrelated DATABASE_URL over this local demo config.
raise "DATABASE_URL is unsupported: use this demo's local database settings" if ENV["DATABASE_URL"].present?
