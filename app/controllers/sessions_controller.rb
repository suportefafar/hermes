class SessionsController < ApplicationController
  def new
    redirect_to dashboard_root_path if current_admin
  end

  def create
    admin = AdminUser.find_by(email: params[:email]&.downcase)
    if admin&.authenticate(params[:password])
      session[:admin_user_id] = admin.id
      redirect_to dashboard_root_path, notice: "Welcome back!"
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_user_id)
    redirect_to login_path, notice: "Signed out."
  end
end
