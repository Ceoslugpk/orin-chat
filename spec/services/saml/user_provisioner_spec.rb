require 'rails_helper'

RSpec.describe Saml::UserProvisioner do
  let(:account) { create(:account) }
  let(:auth) do
    OpenStruct.new(
      info: OpenStruct.new(email: 'new-saml-user@example.test', first_name: 'Saml', last_name: 'User'),
      extra: OpenStruct.new(raw_info: { 'groups' => ['support'] })
    )
  end

  before do
    account.enable_features!('saml')
    create(:account_saml_settings, account: account, sso_url: 'https://idp.example.test/sso',
                                   idp_entity_id: 'https://idp.example.test/metadata',
                                   certificate: saml_test_certificate)
  end

  it 'creates a confirmed user and an agent membership' do
    user = described_class.new(account: account, auth: auth).perform

    expect(user).to be_confirmed
    expect(user.email).to eq('new-saml-user@example.test')
    expect(AccountUser.find_by(account: account, user: user)).to be_agent
  end

  it 'reuses an existing user and membership' do
    user = create(:user, account: account, role: :agent, email: 'new-saml-user@example.test')

    result = described_class.new(account: account, auth: auth).perform

    expect(result).to eq(user)
    expect(AccountUser.where(account: account, user: user).count).to eq(1)
  end

  it 'applies an administrator role mapping' do
    AccountSamlSettings.find_by!(account: account).update!(role_mappings: { 'administrator' => ['support'] })
    user = described_class.new(account: account, auth: auth).perform

    expect(AccountUser.find_by(account: account, user: user)).to be_administrator
  end
end
