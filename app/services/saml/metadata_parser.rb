class Saml::MetadataParser
  class Error < StandardError; end

  Result = Struct.new(:sso_url, :idp_entity_id, :certificate, keyword_init: true)

  SSO_BINDING = 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'.freeze
  MAX_BODY_BYTES = 1.megabyte

  def initialize(url:)
    @url = url
  end

  def fetch
    uri = parse_uri
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    raise Error, 'Metadata request failed' unless response.is_a?(Net::HTTPSuccess)
    raise Error, 'Metadata is too large' if response.body.to_s.bytesize > MAX_BODY_BYTES

    parse(response.body)
  rescue Timeout::Error, SocketError, SystemCallError => e
    raise Error, e.message
  end

  def parse(xml)
    document = Nokogiri::XML(xml)
    entity = xpath(document, '//*[local-name()="EntityDescriptor"]').first
    sso = xpath(document,
                '//*[local-name()="IDPSSODescriptor"]/*[local-name()="SingleSignOnService"][@Binding="' \
                "#{SSO_BINDING}\"]").first
    certificate = signing_certificate(document)
    raise Error, 'Invalid SAML metadata' if entity.blank? || sso.blank? || certificate.blank?

    Result.new(
      sso_url: sso['Location'],
      idp_entity_id: entity['entityID'],
      certificate: certificate_pem(certificate.text)
    )
  end

  private

  attr_reader :url

  def parse_uri
    uri = URI.parse(url)
    raise Error, 'Metadata URL must use HTTPS' unless uri.is_a?(URI::HTTPS)
    raise Error, 'Metadata URL cannot target a private address' if private_host?(uri.host)

    uri
  rescue URI::InvalidURIError
    raise Error, 'Invalid metadata URL'
  end

  def private_host?(host)
    addresses = Resolv.getaddresses(host)
    addresses.empty? || addresses.any? do |address|
      ip = IPAddr.new(address)
      ip.loopback? || ip.private? || ip.link_local? || ip.multicast?
    rescue IPAddr::InvalidAddressError
      false
    end
  end

  def signing_certificate(document)
    xpath(document,
          '//*[local-name()="IDPSSODescriptor"]//*[local-name()="KeyDescriptor"][@use="signing" ' \
          'or not(@use)]//*[local-name()="X509Certificate"]').first ||
      xpath(document, '//*[local-name()="IDPSSODescriptor"]//*[local-name()="X509Certificate"]').first
  end

  def certificate_pem(value)
    body = value.to_s.gsub(/\s+/, '')
    raise Error, 'Missing certificate' if body.blank?

    "-----BEGIN CERTIFICATE-----\n#{body.scan(/.{1,64}/).join("\n")}\n-----END CERTIFICATE-----\n"
  end

  def xpath(document, expression)
    document.xpath(expression)
  end
end
