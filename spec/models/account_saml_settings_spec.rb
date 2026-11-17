require 'rails_helper'

RSpec.describe AccountSamlSettings, type: :model do
  let(:account) { create(:account) }

  def build_settings(attributes = {})
    described_class.new(
      {
        account: account,
        sso_url: 'https://idp.example.test/sso',
        idp_entity_id: 'https://idp.example.test/metadata',
        certificate: saml_test_certificate
      }.merge(attributes)
    )
  end

  it 'is configured with manual IdP fields' do
    settings = build_settings

    expect(settings).to be_valid
    expect(settings).to be_configured
  end

  it 'requires a metadata URL or all manual IdP fields' do
    settings = described_class.new(account: account, sso_url: 'https://idp.example.test/sso')

    expect(settings).not_to be_valid
    expect(settings.errors[:base]).to include('Provide a metadata URL or the IdP SSO URL, entity ID and certificate')
  end

  it 'generates a default SP entity ID and a certificate fingerprint' do
    settings = build_settings
    settings.valid?

    expect(settings.sp_entity_id).to include("/accounts/#{account.id}")
    expect(settings.fingerprint).to match(/\A([0-9A-F]{2}:){31}[0-9A-F]{2}\z/)
  end

  it 'rejects invalid certificates' do
    settings = build_settings(certificate: 'not a certificate')

    expect(settings).not_to be_valid
    expect(settings.errors[:certificate]).to be_present
  end

  it 'requires HTTPS metadata URLs' do
    settings = build_settings(metadata_url: 'http://idp.example.test/metadata')

    expect(settings).not_to be_valid
    expect(settings.errors[:metadata_url]).to be_present
  end
end
