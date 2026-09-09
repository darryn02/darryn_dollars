require 'rails_helper'

RSpec.describe User, type: :model do
  describe "#chump? and #non_chump?" do
    it "is not a chump when admin" do
      user = create_user(admin: true)

      expect(user.chump?).to be(false)
      expect(user.non_chump?).to be(true)
    end

    it "is not a chump when the user is Chad, even without admin" do
      user = create_user
      stub_const("User::CHAD", user.id)

      expect(user.chump?).to be(false)
      expect(user.non_chump?).to be(true)
    end

    it "is a chump when neither admin nor Chad" do
      user = create_user
      stub_const("User::CHAD", user.id + 1)

      expect(user.chump?).to be(true)
      expect(user.non_chump?).to be(false)
    end
  end
end
