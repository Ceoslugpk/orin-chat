require 'rails_helper'

RSpec.describe 'SAML login API', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent, email: 'saml-user@example.test') }

  before do
    account.enable_features!('saml')
    create(:account_saml_settings, account: account)
    user
  end

  it 'redirects an existing user to the OmniAuth SAML request' do
    post '/api/v1/auth/saml_login', params: { email: user.email }, as: :json

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("/omniauth/saml?account_id=#{account.id}")
  end

  it 'accepts an explicit account id' do
    post '/api/v1/auth/saml_login', params: { email: 'unknown@example.test', sso_account_id: account.id }, as: :json

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("/omniauth/saml?account_id=#{account.id}")
  end

  it 'rejects unknown users without an account context' do
    post '/api/v1/auth/saml_login', params: { email: 'unknown@example.test' }, as: :json

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include('error=saml-not-enabled')
  end

  it 'rejects login when SAML is disabled for the account' do
    account.disable_features!('saml')

    post '/api/v1/auth/saml_login', params: { email: user.email }, as: :json

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include('error=saml-not-enabled')
  end
end
