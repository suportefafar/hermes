module Api
  module V1
    class MessagesController < ActionController::API
      before_action :authenticate_client!
      before_action :require_https_for_external!

      def create
        errors = EmailValidator.validate(message_params.to_h)

        if errors.any?
          # Persist as invalid for visibility in dashboard
          EmailMessage.create!(
            api_client:   @current_client,
            status:       :invalid,
            from_address: message_params[:from_address],
            reply_to:     message_params[:reply_to],
            to_addresses: Array(message_params[:to_addresses]),
            cc_addresses: Array(message_params[:cc_addresses]),
            bcc_addresses: Array(message_params[:bcc_addresses]),
            subject:      message_params[:subject],
            body_html:    message_params[:body_html],
            attachments:  message_params[:attachments] || [],
            attempts:     0,
            next_attempt_at: nil
          )
          render json: { errors: errors }, status: :bad_request
          return
        end

        message = EmailMessage.create!(
          api_client:    @current_client,
          status:        :pending,
          from_address:  message_params[:from_address],
          reply_to:      message_params[:reply_to],
          to_addresses:  Array(message_params[:to_addresses]),
          cc_addresses:  Array(message_params[:cc_addresses]),
          bcc_addresses: Array(message_params[:bcc_addresses]),
          subject:       message_params[:subject],
          body_html:     message_params[:body_html],
          attachments:   message_params[:attachments] || [],
          attempts:      0,
          next_attempt_at: Time.current,
          is_manual_resend: false
        )

        SchedulerJob.perform_later

        render json: { id: message.id, status: "accepted" }, status: :accepted
      end

      private

      def authenticate_client!
        token = request.headers["Authorization"]&.gsub(/^Bearer\s+/, "")
        @current_client = ApiClient.find_by_token(token)
        render json: { error: "Unauthorized" }, status: :unauthorized unless @current_client
      end

      def require_https_for_external!
        return if request.ssl?
        return if internal_request?

        render json: { error: "HTTPS required" }, status: :forbidden
      end

      def internal_request?
        ip = IPAddr.new(request.remote_ip)
        [
          IPAddr.new("10.0.0.0/8"),
          IPAddr.new("172.16.0.0/12"),
          IPAddr.new("192.168.0.0/16"),
          IPAddr.new("127.0.0.0/8")
        ].any? { |range| range.include?(ip) }
      rescue IPAddr::InvalidAddressError
        false
      end

      def message_params
        params.permit(
          :from_address, :reply_to, :subject, :body_html,
          to_addresses: [], cc_addresses: [], bcc_addresses: [],
          attachments: [ :filename, :content_type, :content ]
        )
      end
    end
  end
end
