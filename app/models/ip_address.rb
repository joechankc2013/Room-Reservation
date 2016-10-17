require 'ipaddr'
class IpAddress < ApplicationRecord
  validates :ip_address, :ip_address_i, :presence => true
  validate :ip_address_is_ip
  belongs_to :auto_login, optional: true

  def ip_address=(value)
    self.ip_address_i = value
    super
  end

  private

  def ip_address_i=(value)
    begin
      ip_int = IPAddr.new(value)
    rescue
    end
    write_attribute(:ip_address_i, ip_int)
  end

  def ip_address_is_ip
    errors.add(:ip_address, "must be a valid IP address") unless is_ip?(ip_address)
  end

  def is_ip?(value)
    !(IPAddr.new(value) rescue nil).nil?
  end
end
