class AccountSamlSettings < ApplicationRecord
  DEFAULT_NAME_ID_FORMAT = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'.freeze

  belongs_to :account

  validates :account_id, uniqueness: true
  validate :configuration_present
  validate :certificate_is_valid
  validate :metadata_url_is_valid

  before_validation :set_default_sp_entity_id

  def configured?
    metadata_url.present? || (sso_url.present? && certificate.present? && idp_entity_id.present?)
  end

  def fingerprint
    return if certificate.blank?

    digest = OpenSSL::Digest::SHA256.hexdigest(OpenSSL::X509::Certificate.new(certificate).to_der)
    digest.scan(/../).join(':').upcase
  rescue OpenSSL::X509::CertificateError
    nil
  end

  def omniauth_options
    {
      idp_sso_service_url: sso_url,
      idp_cert: certificate,
      idp_entity_id: idp_entity_id,
      sp_entity_id: sp_entity_id,
      assertion_consumer_service_url: acs_url,
      name_identifier_format: DEFAULT_NAME_ID_FORMAT,
      attribute_statements: {
        email: ['email'],
        first_name: ['first_name'],
        last_name: ['last_name']
      }
    }
  end

  private

  def acs_url
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/omniauth/saml/callback?account_id=#{account_id}"
  end

  def set_default_sp_entity_id
    self.sp_entity_id = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/accounts/#{account_id}" if sp_entity_id.blank?
  end

  def configuration_present
    return if configured?

    errors.add(:base, I18n.t('errors.account_saml_settings.configuration_missing'))
  end

  def certificate_is_valid
    return if certificate.blank?

    OpenSSL::X509::Certificate.new(certificate)
  rescue OpenSSL::X509::CertificateError
    errors.add(:certificate, I18n.t('errors.account_saml_settings.invalid_certificate'))
  end

  def metadata_url_is_valid
    return if metadata_url.blank?

    uri = URI.parse(metadata_url)
    return if uri.is_a?(URI::HTTPS) && uri.host.present?

    errors.add(:metadata_url, I18n.t('errors.account_saml_settings.metadata_url.invalid_url'))
  rescue URI::InvalidURIError
    errors.add(:metadata_url, I18n.t('errors.account_saml_settings.metadata_url.invalid_url'))
  end
end
