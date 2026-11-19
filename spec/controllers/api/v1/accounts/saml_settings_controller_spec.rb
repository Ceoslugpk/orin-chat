require 'rails_helper'

RSpec.describe 'SAML settings API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { administrator.create_new_auth_token }

  before { account.enable_features!('saml') }

  it 'is unavailable when the account feature is disabled' do
    account.disable_features!('saml')

    get "/api/v1/accounts/#{account.id}/saml_settings", headers: headers, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'denies agents' do
    get "/api/v1/accounts/#{account.id}/saml_settings",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'creates manual settings with a fingerprint' do
    post "/api/v1/accounts/#{account.id}/saml_settings",
         headers: headers,
         params: {
           saml_settings: {
             sso_url: 'https://idp.example.test/sso',
             idp_entity_id: 'https://idp.example.test/metadata',
             certificate: saml_test_certificate
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['fingerprint']).to be_present
    expect(AccountSamlSettings.count).to eq(1)
  end

  it 'shows, updates and deletes settings' do
    create(:account_saml_settings, account: account)

    get "/api/v1/accounts/#{account.id}/saml_settings", headers: headers, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['sso_url']).to eq('https://idp.example.com/saml/sso')

    put "/api/v1/accounts/#{account.id}/saml_settings",
        headers: headers,
        params: { saml_settings: { sso_url: 'https://idp.example.test/sso-v2' } },
        as: :json
    expect(response).to have_http_status(:success)
    expect(AccountSamlSettings.last.sso_url).to eq('https://idp.example.test/sso-v2')

    delete "/api/v1/accounts/#{account.id}/saml_settings", headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(AccountSamlSettings.count).to eq(0)
  end

  it 'loads identity provider fields from metadata and refreshes them' do
    result = Saml::MetadataParser::Result.new(
      sso_url: 'https://idp.example.test/sso',
      idp_entity_id: 'https://idp.example.test/metadata',
      certificate: saml_test_certificate
    )
    allow_any_instance_of(Saml::MetadataParser).to receive(:fetch).and_return(result) # rubocop:disable RSpec/AnyInstance

    post "/api/v1/accounts/#{account.id}/saml_settings",
         headers: headers,
         params: { saml_settings: { metadata_url: 'https://idp.example.test/metadata' } },
         as: :json

    expect(response).to have_http_status(:created)
    settings = AccountSamlSettings.last
    expect(settings.sso_url).to eq('https://idp.example.test/sso')
    expect(settings.idp_entity_id).to eq('https://idp.example.test/metadata')
    expect(settings.metadata_refreshed_at).to be_present

    post "/api/v1/accounts/#{account.id}/saml_settings/refresh", headers: headers, as: :json
    expect(response).to have_http_status(:success)
  end

  it 'returns 404 when showing settings that do not exist' do
    get "/api/v1/accounts/#{account.id}/saml_settings", headers: headers, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
