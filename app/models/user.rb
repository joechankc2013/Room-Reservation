class User < OpenStruct
  include Draper::Decoratable
  def initialize(name, extra_params={})
    extra_params ||= {}
    extra_params[:onid] = name
    super(extra_params)
  end

  def banner_record
    @banner_record ||= BannerRecord.where(:onid => self.onid).first
  end

  def reservations
    Reservation.where(:user_onid => onid)
  end

  def email
    @email ||= begin
      result = super
      if !result.blank?
        result
      elsif banner_record && !banner_record.email.blank?
        banner_record.email
      else
        ""
      end
    end
  end

  def max_reservation_time
    @max_reservation_time ||= calculate_max_reservation_time
  end

  def nil?
    onid.blank?
  end

  def roles
    Role.where(:onid => onid)
  end

  def role_names
    roles.pluck(:role)
  end

  def staff?
    return false if onid.blank?
    roles = role_names
    role_names.include?("admin") || role_names.include?("staff")
  end

  def admin?
    return false if onid.blank?
    role_names.include?("admin")
  end

  def attributes
    {"onid" => nil}
  end

  private

  def calculate_max_reservation_time
    if staff?
      result ||= reservation_times["admin"]
    end
    if banner_record && banner_record.status
      result ||= reservation_times[banner_record.status.downcase] if reservation_times.has_key?(banner_record.status.downcase)
    end
    result ||= default_reservation_time
    result.to_i*60
  end

  def default_reservation_time
    reservation_times["default"]
  end

  def reservation_times
    Setting.reservation_times
  end

end
