require "minitest/autorun"
require "open3"
require "rbconfig"

class SeedSecurityTest < Minitest::Test
  def seed(password)
    code = <<~RUBY
      class AdminUser
        attr_accessor :password, :password_confirmation
        def self.find_or_create_by!(**)
          yield new
        end
      end
      class SystemSetting
        DEFAULTS = {}.freeze
      end
      load #{File.expand_path('../db/seeds.rb', __dir__).inspect}
    RUBY
    Open3.capture3({ "HERMES_ADMIN_EMAIL" => "admin@example.test", "HERMES_ADMIN_PASSWORD" => password }, RbConfig.ruby, "-e", code)
  end

  def test_does_not_print_provisioned_password
    password = "test-password-for-seed"
    stdout, stderr, status = seed(password)
    assert status.success?, stderr
    refute_includes stdout + stderr, password
    refute_includes stdout + stderr, "Generated admin password"
  end

  def test_missing_or_placeholder_password_fails_without_generating_one
    [ nil, "", "__REQUIRED__" ].each do |password|
      stdout, stderr, status = seed(password)
      refute status.success?
      assert_includes stderr, "HERMES_ADMIN_PASSWORD"
      refute_includes stdout + stderr, "Generated admin password"
    end
  end
end
