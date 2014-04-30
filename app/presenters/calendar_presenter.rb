class CalendarPresenter
  extend ::NewRelic::Agent::MethodTracer
  include Enumerable
  attr_reader :start_time, :end_time, :rooms, :floors, :filters

  def self.cached(start_time, end_time,skip_publish=false)
    key = "Cached/#{form_cache_key(start_time, end_time, Room.all)}"
    result = Rails.cache.read(key)
    if result.nil?
      result = new(start_time, end_time)
      self.class.trace_execution_scoped(['Custom/CachePresenter']) do
        Rails.cache.write(key, result)
      end
      self.publish_changed(start_time, end_time, key) unless skip_publish
    end
    return result
  end
  # Publishes info to Faye
  def self.publish_changed(start_time, end_time, presenter_key=nil)
    FayePublishChangedDates.perform_async(start_time, end_time, presenter_key)
  end

  def initialize(start_time, end_time)
    @start_time = start_time
    @end_time = end_time
    @managers = managers
    @rooms = RoomDecorator.decorate_collection(Room.includes(:filters).order(:floor, :name).load)
    @floors = @rooms.map(&:floor).uniq
    @filters = Filter.all
    sort_events_into_rooms
  end

  def each
    return enum_for(:each) unless block_given?
    event_collection.each do |event|
      yield event
    end
  end

  def event_collection(force=false)
    return @event_collection unless @event_collection.blank? || force
    event_collection = @managers.map{|m| m.events_between(@start_time, @end_time, @rooms)}
                                 .flatten
                                 .sort_by{|e| [e.start_time, e.end_time]}
    fix_event_collisions! event_collection
    @event_collection = event_collection
    return @event_collection
  end

  def self.form_cache_key(start_time, end_time, rooms)
    key = "#{self.to_s}/event_collection/#{start_time.to_i}/#{end_time.to_i}"
    key += Room.order("updated_at DESC").first.try(:cache_key) || ''
    managers.each do |manager|
      if manager.respond_to? :cache_key
        key += "/#{manager.cache_key(start_time, end_time, rooms)}"
      end
    end
    return key
  end

  def cache_key
    return @cache_key if @cache_key
    formed_key = self.class.form_cache_key(start_time, end_time, rooms)
    @cache_key = Rails.cache.fetch("cached_key/#{formed_key}") do
      "#{formed_key}/#{SecureRandom.hex}"
    end
  end

  protected

  def self.managers
    [
        EventManager::ReservationManager.new,
        EventManager::HoursManager.new,
        EventManager::CleaningRecordsManager.new
    ]
  end

  def managers
    @managers ||= self.class.managers
  end

  def sort_events_into_rooms
    all_events = event_collection.group_by(&:room_id)
    rooms.each do |room|
      room.events = all_events[room.id] if all_events.has_key?(room.id)
      room.events = [] if room.events.blank?
      room.decorated_events(start_time)
    end
  end

  def fix_event_collisions! (event_collection)
    event_collection.each do |event|
      next unless event.valid?
      fix_event(event)
      event_collection.each do |event_2|
        next if event == event_2
        # Only fix collisions between events are for the same room.
        next if event.room_id != event_2.room_id
        next unless event_2.valid?
        collide(event, event_2)
      end
    end
    event_collection.delete_if{|event| !event.valid?}
  end

  def fix_event(event)
    event.start_time = @start_time if event.start_time < @start_time
    event.end_time = @end_time if event.end_time > @end_time
  end

  def collide(event, event_2)
    if event.start_time <= event_2.start_time && event_2.start_time <= event.end_time
      if event.priority >= event_2.priority
        event_2.start_time = event.end_time
      else
        event.end_time = event_2.start_time
      end
    end
  end
end
