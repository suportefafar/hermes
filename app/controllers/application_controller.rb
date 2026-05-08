class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def current_admin
    @current_admin ||= AdminUser.find_by(id: session[:admin_user_id])
  end

  def require_admin!
    redirect_to login_path, alert: "Please sign in." unless current_admin
  end

  helper_method :current_admin
end
