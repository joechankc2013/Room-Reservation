class ReservationsController < ApplicationController
  respond_to :json
  include_root_in_json = false
  before_filter :require_login, :only => [:create, :destroy]
  def current_user_reservations
    if params.has_key?(:date)
      date = Time.zone.parse(params[:date])
      result = current_user.reservations.where("start_time <= ? AND end_time >= ?", date.tomorrow.midnight, date.midnight)
    else
      result = current_user.reservations
    end
    respond_with(Array.wrap(result))
  end

  # Returns availability in seconds given a time
  def availability
    available_time = max_availability
    start_time = Time.zone.parse(params[:start])
    room = Room.find(params[:room_id])
    availability_checker = AvailabilityChecker.new(room, start_time, start_time+max_availability)
    unless availability_checker.available?
      available_time = availability_checker.events.first.start_time - start_time
      available_time = 0 if available_time < 0
    end
    respond_with({:availability => available_time.to_i})
  end

  def create
    params["reservation"]["reserver_onid"] = current_user.onid
    reserver = Reserver.from_params(params)
    reserver.save
    respond_with(reserver, :location => root_path, :location => root_path, :responder => JsonResponder)
  end

  def destroy
    reservation = Reservation.find(params[:id])
    canceller = Canceller.new(reservation, current_user)
    canceller.save
    respond_with(canceller, :location => root_path, :responder => JsonResponder)
  end


  protected

  # @TODO: Make this configurable
  def max_availability
    6.hours
  end

  def default_serializer_options
    {
        root: false
    }
  end
end