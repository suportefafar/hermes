class EmailValidator
  REQUIRED = %w[to_addresses subject body_html].freeze

  def self.validate(params)
    errors = []

    REQUIRED.each do |field|
      if params[field].blank?
        errors << "#{field} is required"
      end
    end

    # Validate email addresses
    address_fields = { "to_addresses" => true, "cc_addresses" => false, "bcc_addresses" => false,
                       "from_address" => false, "reply_to" => false }

    address_fields.each do |field, required|
      value = params[field]
      next if value.blank? && !required

      addresses = normalize_addresses(value)
      addresses.each do |addr|
        unless valid_email?(addr)
          errors << "#{field} contains invalid address: #{addr}"
        end
      end
    end

    errors
  end

  def self.valid_email?(addr)
    addr.match?(URI::MailTo::EMAIL_REGEXP)
  end

  # Accepts a String ("a@x.com,b@x.com"), an Array, or nil.
  # Always returns a plain Array of trimmed, non-blank addresses.
  def self.normalize_addresses(value)
    case value
    when Array
      value.flat_map { |v| v.to_s.split(",") }.map(&:strip).reject(&:blank?)
    when String
      value.split(",").map(&:strip).reject(&:blank?)
    else
      []
    end
  end
end
