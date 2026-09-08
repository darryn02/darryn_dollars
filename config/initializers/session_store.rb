# Be sure to restart your server when you modify this file.

# domain: :all scopes the cookie to ".darryndollars.com" rather than the exact
# host, so a session survives moving between the apex and www. Without it,
# changing which host is canonical signs everyone out, and a stray link to the
# non-canonical host costs a round trip through the login page.
#
# Rails omits the domain entirely for single-label hosts, so localhost in
# development and test is unaffected.
Rails.application.config.session_store :cookie_store,
                                       key: '_darryn_dollars_session',
                                       domain: :all
