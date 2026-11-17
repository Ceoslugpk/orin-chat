require 'rails_helper'

RSpec.describe Saml::MetadataParser do
  it 'extracts the redirect SSO URL, entity ID and signing certificate' do
    result = described_class.new(url: 'https://idp.example.test/metadata').parse(saml_metadata_xml)

    expect(result.sso_url).to eq('https://idp.example.test/sso')
    expect(result.idp_entity_id).to eq('https://idp.example.test/metadata')
    expect(result.certificate).to include('BEGIN CERTIFICATE')
    expect { OpenSSL::X509::Certificate.new(result.certificate) }.not_to raise_error
  end

  it 'rejects metadata without a certificate' do
    xml = saml_metadata_xml.sub(%r{<md:KeyDescriptor.*?</md:KeyDescriptor>}m, '')

    expect do
      described_class.new(url: 'https://idp.example.test/metadata').parse(xml)
    end.to raise_error(Saml::MetadataParser::Error)
  end

  it 'refuses HTTP metadata URLs' do
    expect do
      described_class.new(url: 'http://idp.example.test/metadata').fetch
    end.to raise_error(Saml::MetadataParser::Error, /HTTPS/)
  end
end
