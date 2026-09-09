require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#last_seen_label" do
    it "says never visited when there is no timestamp at all" do
      user = create_user

      expect(helper.last_seen_label(user)).to eq("Never visited")
    end

    it "renders a relative time when there is one" do
      user = create_user
      user.update_column(:last_seen_at, 3.days.ago)

      expect(helper.last_seen_label(user)).to match(/Last seen.*3 days ago/)
    end
  end
end
