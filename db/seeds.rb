AdminUser.find_or_create_by!(email: ENV.fetch("HERMES_ADMIN_EMAIL", "admin@hermes.farmacia.ufmg.br")) do |u|
  u.password              = ENV.fetch("HERMES_ADMIN_PASSWORD", SecureRandom.hex(16).tap { |p| puts "⚠️  Generated admin password: #{p}" })
  u.password_confirmation = u.password
end

SystemSetting::DEFAULTS.each do |key, value|
  SystemSetting.find_or_create_by!(key: key) { |s| s.value = value }
end

puts "✅  Hermes seeded."
