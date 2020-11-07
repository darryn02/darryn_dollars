require 'rails_helper'

RSpec.describe Account, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:betting_slips) }
end
