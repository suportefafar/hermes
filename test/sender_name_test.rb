require "minitest/autorun"
require "action_mailer"
require "active_support/core_ext"
require "ostruct"
require_relative "../app/mailers/application_mailer"
require_relative "../app/mailers/hermes_mailer"
require_relative "../app/services/email_validator"

class SenderNameTest < Minitest::Test
  def test_sender_name_preserves_provider_address
    mailer = HermesMailer.new
    captured = nil
    mailer.define_singleton_method(:mail) { |**options| captured = options }
    message = OpenStruct.new(body_html: "<p>Teste</p>", subject: "Teste", attachments: [],
      to_addresses: [ "person@example.test" ], from_name: "Intranet FAFAR")
    provider = OpenStruct.new(host: "smtp.example.test", port: 587, from_address: "sender@example.test")
    mailer.send_email(message, provider)
    address = Mail::Address.new(captured.fetch(:from))
    assert_equal "Intranet FAFAR", address.display_name
    assert_equal "sender@example.test", address.address
    message.from_name = nil
    mailer.send_email(message, provider)
    assert_equal "sender@example.test", captured.fetch(:from)
  end

  def test_rejects_header_injection
    params = { "to_addresses" => [ "person@example.test" ], "subject" => "Teste", "body_html" => "Teste", "from_name" => "Bad\r\nBcc: other@example.test" }
    assert_includes EmailValidator.validate(params), "from_name is invalid"
    params["from_name"] = "Intranet FAFAR"
    assert_empty EmailValidator.validate(params)
  end
end
