class HermesMailer < ApplicationMailer
  # Dynamically configure SMTP per provider at send time
  def send_email(message, provider)
    @body_html = normalize_body_html(message.body_html)
    @subject   = message.subject

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

    # Attach files before calling mail (so they are included in the message)
    message.attachments.each do |attachment|
      attachments[attachment["filename"]] = {
        mime_type: attachment["content_type"],
        content:   Base64.decode64(attachment["content"])
      }
    end

    mail(
      to:          message.to_addresses,
      cc:          message.cc_addresses.presence,
      bcc:         message.bcc_addresses.presence,
      from:        message.from_address.presence || provider.from_address,
      reply_to:    message.reply_to.presence,
      subject:     message.subject,
      delivery_method_options: smtp_settings
    )
  end

  private

  # Detects whether the body is plain text (no HTML block elements present)
  # and if so converts it to basic HTML so formatting is preserved.
  # HTML inputs are returned as-is.
  HTML_BLOCK_TAGS = %r{<(p|div|table|ul|ol|li|h[1-6]|br|hr|pre|blockquote)[^>]*>}i

  def normalize_body_html(body)
    return body if body.match?(HTML_BLOCK_TAGS)

    # Plain-text path: escape, then restore line breaks and basic Markdown-ish markers
    safe = ERB::Util.html_escape(body)
    safe = safe.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')  # **bold**
    safe = safe.gsub(/\*(.+?)\*/,     '<em>\1</em>')          # *italic*
    safe = safe.gsub("\n", "<br>\n")
    safe
  end
end
