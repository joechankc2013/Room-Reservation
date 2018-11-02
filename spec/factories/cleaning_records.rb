# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :cleaning_record do
    start_date "2013-08-22"
    end_date "2013-08-22"
    start_time "2013-08-22 05:00:00"
    end_time "2013-08-22 12:00:00"
    weekdays [0,1,2,3,4,5,6]
  end
end
