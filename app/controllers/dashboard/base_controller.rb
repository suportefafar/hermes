module Dashboard
  class BaseController < ApplicationController
    before_action :require_admin!
    layout "dashboard"
  end
end
