module Dashboard
  class MessagesController < BaseController
    def index
      @messages = EmailMessage.includes(:api_client)

      @messages = @messages.where(status: params[:status]) if params[:status].present? && EmailMessage.statuses.key?(params[:status])

      if params[:q].present?
        q = "%#{params[:q]}%"
        @messages = @messages.where(
          "subject ILIKE :q OR from_address ILIKE :q OR to_addresses::text ILIKE :q",
          q: q
        )
      end

      if params[:client_id].present?
        @messages = @messages.where(api_client_id: params[:client_id])
      end

      @messages = @messages.order(created_at: :desc).page(params[:page]).per(25)
      @clients  = ApiClient.order(:name)
    end

    def show
      @message  = EmailMessage.includes(:api_client, :smtp_provider, delivery_attempts: :smtp_provider).find(params[:id])
      @attempts = @message.delivery_attempts.order(:attempted_at)
    end

    def resend
      @message = EmailMessage.find(params[:id])

      if @message.pending?
        redirect_to dashboard_message_path(@message), alert: "Message is already pending."
        return
      end

      @message.enqueue_manual_resend!
      redirect_to dashboard_message_path(@message), notice: "Message queued for resend."
    end
  end
end
