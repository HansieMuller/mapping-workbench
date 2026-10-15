# Seed only this demo's dedicated local database. The random password stays untracked.
raise "Seeds are local-only" unless Rails.env.development? || Rails.env.test?
user = User.find_or_initialize_by(email: "operator@example.test")
unless user.persisted?
  password = SecureRandom.base58(24)
  user.password = password
  user.save!
  path = Rails.root.join("tmp/demo_password")
  File.write(path, password, mode: "w", perm: 0o600)
end
event = Event.find_or_create_by!(name: "Moonfern Trail Festival", event_date: Date.new(2026, 9, 19))
event.races.find_or_create_by!(name: "Copper Loop", distance: "10km")
