class User < ApplicationRecord
  CHAD = ENV.fetch("CHAD_USER_ID", 8).to_i

  devise :invitable, :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable, :timeoutable

  # Ordered because "the first account" is a thing the views ask for, and
  # unordered it meant whatever Postgres returned: saving one account's row
  # moved it behind its sibling, and which account came first flipped.
  #
  # inverse_of is spelled out because a scope switches off Rails own
  # detection of it, and Account#display_name walks back up to its siblings.
  has_many :accounts, -> { order(:id) }, inverse_of: :user
  has_many :wagers, through: :accounts

  after_invitation_accepted :provision_starter_account!

  # Carries the new player's leaderboard choices from the accept-invitation
  # form through to provision_starter_account! - not real columns, since they
  # describe the one Account this creates, not the User itself.
  attr_accessor :account_nickname, :account_leaderboard_visible

  # devise_invitable's own User.invite!(email: ...) saves the bare, freshly
  # invited row with validate: false (validate_on_invite defaults to false),
  # so this never blocks sending an invitation - it only ever fires for the
  # save that accepts one, and for every normal save after that.
  validates :name, presence: true

  def self.list_all
    all.map { |u| "[#{u.id}] #{u.name}, #{u.mobile}, #{u.email}"}
  end

  def chump?
    !admin? && id != CHAD
  end

  def non_chump?
    !chump?
  end

  private

  # This app does not yet offer creating more than one account per person, so
  # accepting an invitation is also how a brand new player gets their first
  # (and today, only) one.
  def provision_starter_account!
    accounts.create!(
      credit_limit: Account::DEFAULT_CREDIT_LIMIT,
      nickname: account_nickname.presence || name.to_s.split.first,
      leaderboard_visible: ActiveModel::Type::Boolean.new.cast(account_leaderboard_visible) || false
    )
  end
end
