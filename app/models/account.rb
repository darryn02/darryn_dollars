class Account < ApplicationRecord
  CHAD = ENV.fetch("CHAD_ACCOUNT_ID", 7).to_i

  # Starting credit for a player who joins through an invitation. Every
  # account before this one was set up by hand at whatever number seemed
  # right for that person; this is only a starting point for a new player,
  # not a policy - nothing stops it being adjusted afterward the same way
  # every other account's limit already is, by hand.
  DEFAULT_CREDIT_LIMIT = ENV.fetch("DEFAULT_CREDIT_LIMIT", 1_000).to_i

  # What a player can pick as an account's avatar. A fixed list rather than
  # any emoji at all: a free text field would have to decide what counts as
  # one emoji (flags, skin tones and joined sequences are several code points
  # each), and a list of faces that read at 24px is all the avatar needs.
  # Fifteen, so that with the initials choice ahead of them the picker fills
  # two rows of eight on a phone.
  EMOJI_CHOICES = %w[🐻 🐭 🦁 🐯 🦊 🐶 🦅 🦈 🐢 🦉 🎲 🔥 💎 👑 ⚡].freeze

  belongs_to :user
  has_many :bet_slips
  has_many :wagers, through: :bet_slips
  has_many :payments

  validates :emoji, inclusion: { in: EMOJI_CHOICES }, allow_blank: true

  def self.list_all
    Account.includes(:user, wagers: { line: { game: :contestants } }).map do |account|
      [
        "[#{account.id}]",
        account.user.name,
        "(#{account.name || "Primary"})",
        "#{ActionController::Base.helpers.number_to_currency(account.wagers.sum(&:net))}"
      ].join(" ")
    end
  end

  def to_s
    (nickname || name).to_s
  end

  # What a player calls one of their own accounts when they are choosing
  # between them: on the bet sheet, on a slip, in the confirmation.
  #
  # name comes first because it is what the bet sheet dropdown and the slip
  # titles already showed, so it is what a player with two accounts has been
  # reading. nickname is the leaderboard handle and is the fallback - when
  # there is no name, or when a sibling account has the same one, since two
  # choices labelled alike is the mistake this exists to prevent. The last
  # resort is the id, so the label is never blank.
  def display_name
    [:name, :nickname].each do |field|
      label = self[field].to_s.squish
      next if label.blank?

      return label if user.accounts.none? { |other| other.id != id && other[field].to_s.squish.casecmp?(label) }
    end

    name.to_s.squish.presence || nickname.to_s.squish.presence || "Account ##{id}"
  end

  def qualified_name
    if to_s.downcase.strip == "default"
      user.name
    else
      "#{user.name} #{to_s.present? ? "(#{to_s})" : ''}".squish
    end
  end

  def balance
    @balance ||= compute_balance
  end

  def winnings
    @winnings ||= initial_balance + wager_sum
  end

  def compute_balance
    winnings + payment_sum
  end

  def wager_sum
    if wagers.loaded?
      wagers.sum(&:net)
    else
      wagers.sum(:net)
    end
  end

  def payment_sum
    if payments.loaded?
      payments.sum(&:amount)
    else
      payments.sum(:amount)
    end
  end

  def win_sum
    if wagers.loaded?
      wagers.select(&:win?).sum(&:net)
    else
      wagers.win.sum(:net)
    end
  end

  def lose_sum
    if wagers.loaded?
      wagers.select(&:loss?).sum(&:net)
    else
      wagers.loss.sum(:net)
    end
  end

  # What this account can still put at risk. The one definition, so the
  # figure shown beside an account on the bet sheet cannot drift from the
  # check that refuses a wager at confirmation.
  def available_credit
    credit_limit + balance - liabilities
  end

  def liabilities
    if wagers.loaded?
      wagers.confirmed.sum(&:amount)
    else
      wagers.confirmed.sum(:amount)
    end
  end
end
