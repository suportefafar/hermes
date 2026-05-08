module Dashboard
  class ClientsController < BaseController
    before_action :set_client, only: %i[show toggle_active]

    def index
      @clients = ApiClient.order(:name)
    end

    def new
      @client = ApiClient.new
    end

    def create
      @raw_token = ApiClient.generate_token
      @client = ApiClient.new(client_params)
      @client.token = @raw_token
      @client.active = true

      if @client.save
        # Show token once — it won't be retrievable again
        render :show_token
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def toggle_active
      @client.update!(active: !@client.active)
      redirect_to dashboard_clients_path, notice: "Client #{@client.active? ? 'activated' : 'revoked'}."
    end

    private

    def set_client
      @client = ApiClient.find(params[:id])
    end

    def client_params
      params.require(:api_client).permit(:name)
    end
  end
end
