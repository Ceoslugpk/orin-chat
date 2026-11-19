# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
require 'omniauth-saml'

OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }

  provider :saml, name: :saml, setup: lambda { |env|
    request = Rack::Request.new(env)
    session = env['rack.session'] || {}
    account_id = request.params['account_id'].presence || session['saml_account_id']
    settings = AccountSamlSettings.find_by(account_id: account_id)
    raise OmniAuth::Error, 'SAML is not configured for this account' unless settings&.configured? && settings.account.feature_enabled?('saml')

    env['omniauth.strategy'].options.merge!(settings.omniauth_options)
  }
end
