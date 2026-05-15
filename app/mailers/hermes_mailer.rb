class HermesMailer < ApplicationMailer
  # Dynamically configure SMTP per provider at send time
  def send_email(message, provider)
    smtp_settings = {
      address:              provider.host,
      port:                 provider.port,
      user_name:            provider.username,
      password:             provider.password,
      authentication:       :login,
      enable_starttls_auto: provider.port != 465,
      open_timeout:         10,
      read_timeout:         10
    }.compact

    smtp_settings[:ssl] = true if provider.port == 465

    mail(
      to:          message.to_addresses,
      cc:          message.cc_addresses.presence,
      bcc:         message.bcc_addresses.presence,
      from:        message.from_address.presence || provider.from_address,
      reply_to:    message.reply_to.presence,
      subject:     message.subject,
      delivery_method_options: smtp_settings
    ) do |format|
      format.html { render plain: message.body_html, content_type: "text/html" }
    end

    # Attach files if any
    message.attachments.each do |attachment|
      attachments[attachment["filename"]] = {
        mime_type: attachment["content_type"],
        content:   Base64.decode64(attachment["content"])
      }
    end
  end
end
