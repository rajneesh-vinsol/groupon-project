class Admin::BaseController < ApplicationController

  before_action :ensure_user_is_admin
  
  layout 'admin/layouts/admin'

  private def ensure_user_is_admin
    unless current_user.admin?
      redirect_to home_page_path, danger: t('.not_admin')
    end
  end

end
