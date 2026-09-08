# Be sure to restart your server when you modify this file.

# domain: :all scopes the cookie to ".darryndollars.com" rather than the exact
# host, so a session survives moving between the apex and www. Without it,
# changing which host is canonical signs everyone out, and a stray link to the
# non-canonical host costs a round trip through the login page.
#
# Rails omits the domain entirely for single-label hosts, so localhost in
# development and test is unaffected.
#
# expire_after gives the cookie a life of its own. Without it this is a browser
# session cookie, so it dies whenever the browser decides the tab session is
# over - which on a phone means backgrounding the app or memory pressure. That
# is the whole usage pattern here, and it is why sign_in_count had reached four
# figures for some players. Devise's :timeoutable still caps the session at
# config.timeout_in on top of this.
Rails.application.config.session_store :cookie_store,
                                       key: '_darryn_dollars_session',
                                       domain: :all,
                                       expire_after: 2.weeks
