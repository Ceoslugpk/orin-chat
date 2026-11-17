module SamlCertificateHelper
  def saml_test_certificate
    @saml_test_certificate ||= begin
      key = OpenSSL::PKey::RSA.new(2048)
      certificate = OpenSSL::X509::Certificate.new
      certificate.version = 2
      certificate.serial = 1
      certificate.subject = OpenSSL::X509::Name.parse('/CN=saml-test-idp')
      certificate.issuer = certificate.subject
      certificate.public_key = key.public_key
      certificate.not_before = Time.zone.now - 60
      certificate.not_after = Time.zone.now + 1.hour
      certificate.sign(key, OpenSSL::Digest.new('SHA256'))
      certificate.to_pem
    end
  end

  def saml_test_certificate_body
    Base64.strict_encode64(OpenSSL::X509::Certificate.new(saml_test_certificate).to_der)
  end

  def saml_metadata_xml(sso_url: 'https://idp.example.test/sso', entity_id: 'https://idp.example.test/metadata')
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
                           xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
                           entityID="#{entity_id}">
        <md:IDPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
          <md:KeyDescriptor use="signing">
            <ds:KeyInfo>
              <ds:X509Data>
                <ds:X509Certificate>#{saml_test_certificate_body}</ds:X509Certificate>
              </ds:X509Data>
            </ds:KeyInfo>
          </md:KeyDescriptor>
          <md:SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                                  Location="#{sso_url}" />
        </md:IDPSSODescriptor>
      </md:EntityDescriptor>
    XML
  end
end

RSpec.configure do |config|
  config.include SamlCertificateHelper
end
