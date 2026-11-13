admin_email = ENV.fetch("HERMES_ADMIN_EMAIL")
raise ArgumentError, "HERMES_ADMIN_EMAIL must be configured" if admin_email.strip.empty? || admin_email.include?("__REQUIRED__")

AdminUser.find_or_create_by!(email: admin_email) do |u|
  password = ENV.fetch("HERMES_ADMIN_PASSWORD")
  if password.length < 12 || password.include?("__REQUIRED__")
    raise ArgumentError, "HERMES_ADMIN_PASSWORD must contain at least 12 characters"
  end
  u.password = password
  u.password_confirmation = password
end

SystemSetting::DEFAULTS.each do |key, value|
  SystemSetting.find_or_create_by!(key: key) { |s| s.value = value }
end

puts "✅  Hermes seeded."
