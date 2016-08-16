require 'ipaddr'
class ApplicationController < ActionController::Base
  protect_from_forgery

  before_action :set_paper_trail_whodunnit

  protected

  def current_user
    @current_user ||= UserDecorator.new(User.new(current_user_username, current_user_extra_attributes))
  end
  helper_method :current_user

  def user_for_paper_trail
    current_user.onid.to_s
  end

  def patron_mode?
    return true unless current_user.admin?
    !!!session[:patron_mode_disabled]
  end

  def require_login
    redirect_to login_path(:source => request.original_fullpath) if current_user.nil?
  end

  private

  def current_user_username
    ip_login_username || cas_username
  end

  def cas_username
    session[RubyCAS::Filter.client.username_session_key]
  end

  def ip_login_username
    ip = IPAddr.new(request.remote_ip).to_i
    ip_addr = IpAddress.joins(:auto_login).where(:ip_address_i => ip).first
    return ip_addr.try(:auto_login).try(:username)
  end

  def current_user_extra_attributes
    session[RubyCAS::Filter.client.extra_attributes_session_key]
  end
end
