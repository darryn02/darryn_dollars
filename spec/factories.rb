FactoryGirl.define do
  factory :betting_slip do
    user nil
    confirmed false
  end
  factory :line do
    contestant nil
    hidden false
  end
  factory :wager do
    user nil
    line nil
    placed_at "2017-08-01 19:51:38"
    amount_wagered "9.99"
    vig 1.5
    result 1
    net "9.99"
  end
  factory :user do
    admin false
  end
  factory :competitor do

  end
  factory :contestant do
    contest nil
    competitor nil
  end
  factory :contest do
    game nil
  end
  factory :game do
    starts_at "2017-08-01 19:47:58"
  end
end
