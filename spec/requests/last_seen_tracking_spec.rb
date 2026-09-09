require "rails_helper"

# Devise's own last_sign_in_at only moves at login, and sessions here last up
# to six months, so it stops meaning "was here recently" almost immediately.
# This is the site's own record of that, stamped on every authenticated
# request rather than just a login.
RSpec.describe "Tracking when a user was last seen", type: :request do
  let(:user) { create_user }
  let!(:account) { create_account(user: user) }

  it "stamps last_seen_at the first time a signed-in user hits any page" do
    expect(user.last_seen_at).to be_nil

    sign_in user
    get lines_path

    expect(user.reload.last_seen_at).to be_within(30.seconds).of(Time.current)
  end

  it "does not touch it for an anonymous request" do
    get new_user_session_path

    expect(user.reload.last_seen_at).to be_nil
  end

  it "does not move it forward on every request within the resolution window" do
    sign_in user
    get lines_path
    first_stamp = user.reload.last_seen_at

    Timecop.travel(1.minute.from_now) do
      get lines_path
      expect(user.reload.last_seen_at).to eq(first_stamp)
    end
  end

  it "moves it forward once the resolution window has passed" do
    sign_in user
    get lines_path
    first_stamp = user.reload.last_seen_at

    Timecop.travel(6.minutes.from_now) do
      get lines_path
      expect(user.reload.last_seen_at).to be > first_stamp
    end
  end

  it "does not disturb updated_at, which Devise's own tracking relies on" do
    sign_in user
    get lines_path

    expect(user.reload.updated_at).to be_within(30.seconds).of(user.created_at)
  end
end
