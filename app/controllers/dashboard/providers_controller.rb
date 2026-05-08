module Dashboard
  class ProvidersController < BaseController
    before_action :set_provider, only: %i[edit update destroy toggle_active]

    def index
      @providers = SmtpProvider.order(:priority)
    end

    def new
      @provider = SmtpProvider.new
    end

    def create
      @provider = SmtpProvider.new(provider_params)
      @provider.failure_count = 0

      if @provider.save
        redirect_to dashboard_providers_path, notice: "Provider created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @provider.update(provider_params)
        redirect_to dashboard_providers_path, notice: "Provider updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @provider.destroy
      redirect_to dashboard_providers_path, notice: "Provider deleted."
    end

    def toggle_active
      @provider.update!(active: !@provider.active)
      redirect_to dashboard_providers_path, notice: "Provider #{@provider.active? ? 'activated' : 'deactivated'}."
    end

    private

    def set_provider
      @provider = SmtpProvider.find(params[:id])
    end

    def provider_params
      params.require(:smtp_provider).permit(
        :name, :host, :port, :username, :password,
        :from_address, :priority, :active
      )
    end
  end
end
