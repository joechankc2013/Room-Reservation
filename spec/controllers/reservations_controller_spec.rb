require 'spec_helper'

describe ReservationsController do
  before(:each) do
    Timecop.travel(Date.new(2013,9,5))
    User.any_instance.stub(:max_reservation_time).and_return(6.hours)
  end
  describe "current_user_reservations" do
    context "when a user is not logged in" do
      before(:each) do
        get :current_user_reservations, :format => :json
      end
      it "should return a blank JSON array" do
        expect(JSON.parse(response.body)).to eq []
      end
    end
    context "when a user is logged in" do
      let(:user) {build(:user)}
      before(:each) do
        RubyCAS::Filter.fake(user.onid)
        RubyCAS::Filter.filter(self)
      end
      context "when there are no reservations" do
        before(:each) do
          get :current_user_reservations, :format => :json
        end
        it "should return a blank JSON array" do
          expect(JSON.parse(response.body)).to eq []
        end
      end
      context "when another user has a reservation" do
        before(:each) do
          create(:reservation, start_time: Time.current+2.hours, end_time: Time.current+4.hours, user_onid: "dude")
          get :current_user_reservations, :format => :json
        end
        it "should return a blank JSON array" do
          expect(JSON.parse(response.body)).to eq []
        end
      end
      context "when the user has a reservation" do
        context "and the current day is requested" do
          context "and it's before the current day" do
            before(:each) do
              create(:reservation, start_time: Time.current.midnight-4.hours, end_time: Time.current.midnight-2.hours, user_onid: user.onid)
              get :current_user_reservations, :format => :json, :date => "2013-9-5"
            end
            it "should return a blank JSON array" do
              expect(JSON.parse(response.body)).to eq []
            end
          end
          context "and it's to come" do
            before(:each) do
              create(:reservation, start_time: Time.current+2.hours, end_time: Time.current+4.hours, user_onid: user.onid)
              get :current_user_reservations, :format => :json, :date => "2013-9-5"
            end
            it "should return a JSON array containing the reservation" do
              expect(JSON.parse(response.body).length).to eq 1
            end
            context "and the user is not an admin" do
              %w{reserver_onid room_id}.each do |key|
                it "should not include #{key}" do
                  expect(JSON.parse(response.body).first.keys).not_to include("room_id")
                end
              end
            end
            context "and the user is staff" do
              let(:user) {build(:user, :staff)}
              %w{reserver_onid room_id}.each do |key|
                it "should include #{key}" do
                  expect(JSON.parse(response.body).first.keys).to include("room_id")
                end
              end
            end
          end
          context "and it's after the current day" do
            before(:each) do
              create(:reservation, start_time: Time.current.tomorrow.midnight+2.hours, end_time: Time.current.tomorrow.midnight+4.hours, user_onid: user.onid)
              get :current_user_reservations, :format => :json, :date => "2013-9-5"
            end
            it "should return a blank JSOn array" do
              expect(JSON.parse(response.body)).to eq []
            end
          end
        end
        context "and no day is given" do
          before(:each) do
            2.times {create(:reservation, start_time: Time.current.midnight-4.hours, end_time: Time.current.midnight-2.hours, user_onid: user.onid)}
            get :current_user_reservations, :format => :json
          end
          it "should return all reservations" do
            expect(JSON.parse(response.body).length).to eq 2
          end
        end
      end
    end
  end

  describe "create" do
    context "when a user is not logged in" do
      before(:each) do
        post :create
      end
      it "should redirect" do
        expect(response).to redirect_to(login_path(:source => request.original_fullpath))
      end
    end
  end



  describe "availability" do
    before(:each) do
      @room = create(:room)
    end
    context "when there is nothing blocking availability" do
      before(:each) do
        #create(:special_hour, start_date: Date.yesterday, end_date: Date.tomorrow, open_time: "00:00:00", close_time: "00:00:00")
      end
      it "should return the max available time" do
        get :availability, :start => (Time.current.midnight+2.hours).iso8601, :room_id => @room.id, :format => :json
        expect(JSON.parse(response.body)["availability"]).to eq 6.hours
      end
    end
    context "when the hours are blocking availability" do
      it "should return 0" do
        get :availability, :start => (Time.current.midnight+2.hours).iso8601, :room_id => @room.id,  :format => :json
        expect(JSON.parse(response.body)["availability"]).to eq 0
      end
    end
    context "when there is a reservation" do
      before(:each) do
        # Free up hours
        #create(:special_hour, start_date: Date.yesterday, end_date: Date.tomorrow, open_time: "00:00:00", close_time: "00:00:00")
      end
      context "in the next day" do
        before(:each) do
          create(:reservation, :start_time => Time.current.tomorrow.midnight+2.hours, :end_time => Time.current.tomorrow.midnight+4.hours, :room => @room)
          get :availability, :start => (Time.current.midnight+23.hours).iso8601, :room_id => @room.id, :format => :json
        end
        it "should return the number of seconds until that reservation" do
          expect(JSON.parse(response.body)["availability"]).to eq 3.hours-10.minutes
        end
      end
      context "in the same day" do
        context "ending before the request" do
          before(:each) do
            create(:reservation, :start_time => Time.current.midnight+12.hours, :end_time => Time.current.midnight+14.hours-10.minutes, :room => @room)
            get :availability, :start => (Time.current.midnight+14.hours).iso8601, :room_id => @room.id, :format => :json
          end
          it "should return the max availability" do
            expect(JSON.parse(response.body)["availability"]).to eq 6.hours
          end
        end
        context "ending inside the request" do
          before(:each) do
            create(:reservation, :start_time => Time.current.midnight+12.hours, :end_time => Time.current.midnight+14.hours-10.minutes, :room => @room)
            get :availability, :start => (Time.current.midnight+13.hours).iso8601, :room_id => @room.id, :format => :json
          end
          it "should return 0 seconds" do
            expect(JSON.parse(response.body)["availability"]).to eq 0
          end
        end
      end
      context "from the previous day" do
        context "ending inside the request" do
          before(:each) do
            create(:reservation, :start_time => Time.current.midnight-2.hours, :end_time => Time.current.midnight+6.hours, :room => @room)
            get :availability, :start => (Time.current.midnight+4.hours).iso8601, :room_id => @room.id, :format => :json
          end
          it "should return 0 seconds" do
            expect(JSON.parse(response.body)["availability"]).to eq 0
          end
        end
      end
    end
  end

  describe "GET 'index'" do
    before(:each) do
      RubyCAS::Filter.fake("bla")
    end
    it "returns http success" do
      get 'index'
      response.should be_success
    end
  end

end
