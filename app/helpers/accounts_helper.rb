# How one account is told from another at a glance. Only ever shown to
# somebody choosing between several accounts; a player with one never sees
# any of it.
module AccountsHelper
  # Must match the length of $account-colors in base/_theme.scss.
  ACCOUNT_COLORS = 4

  # A colour slot by the account's place among its owner's accounts, so the
  # first is always the same colour and the second always the other one.
  # Position rather than a stored column: User#accounts has a fixed order
  # and there is nothing for a player to configure.
  def account_color_class(account)
    slot = account.user.accounts.index(account).to_i % ACCOUNT_COLORS

    "dd-acct--#{slot}"
  end

  # "BJ" for Big Joe, "M" for Main.
  def account_initials(account)
    words = account.display_name.scan(/[[:alnum:]]+/)

    words.first(2).map { |word| word[0] }.join.upcase
  end

  # Decorative: every place this is drawn also spells the account's name out,
  # so a screen reader gets the name once rather than the initials and then
  # the name.
  def account_avatar(account, css_class: nil)
    tag.span(account_initials(account),
             class: ["dd-acct-avatar", account_color_class(account), css_class].compact.join(" "),
             aria: { hidden: true })
  end

  # Account#liabilities is a query on every call, and the lines board draws a
  # bet sheet per line - dozens of them, each naming every account.
  def available_credit(account)
    @available_credit ||= {}
    @available_credit[account.id] ||= [account.available_credit, 0].max
  end
end
