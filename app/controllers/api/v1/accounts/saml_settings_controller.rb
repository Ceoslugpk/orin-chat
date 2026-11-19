class Api::V1::Accounts::SamlSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :ensure_saml_enabled
  before_action :fetch_saml_settings, only: [:show, :destroy, :refresh]

  def show
    head :not_found if @saml_settings.blank?
  end

  def create
    @saml_settings = AccountSamlSettings.find_or_initialize_by(account: Current.account)
    assign_and_save
  end

  def update
    @saml_settings = AccountSamlSettings.find_or_initialize_by(account: Current.account)
    assign_and_save
  end

  def destroy
    @saml_settings&.destroy!
    head :ok
  end

  def refresh
    return head :not_found if @saml_settings.blank?
    return render_could_not_create_error(I18n.t('errors.account_saml_settings.metadata_url.missing')) if @saml_settings.metadata_url.blank?

    apply_metadata
    @saml_settings.save!
    render :show
  end

  private

  def ensure_saml_enabled
    head :not_found unless Current.account.feature_enabled?('saml')
  end

  def fetch_saml_settings
    @saml_settings = AccountSamlSettings.find_by(account_id: Current.account.id)
  end

  def assign_and_save
    @saml_settings.assign_attributes(saml_settings_params)
    return unless apply_metadata

    @saml_settings.save!
    render :show, status: action_name == 'create' ? :created : :ok
  end

  def apply_metadata
    return true if @saml_settings.metadata_url.blank?

    result = Saml::MetadataParser.new(url: @saml_settings.metadata_url).fetch
    @saml_settings.assign_attributes(
      sso_url: result.sso_url,
      idp_entity_id: result.idp_entity_id,
      certificate: result.certificate,
      metadata_refreshed_at: Time.current
    )
    true
  rescue Saml::MetadataParser::Error => e
    render json: { errors: [e.message] }, status: :unprocessable_content
    false
  end

  def saml_settings_params
    params.require(:saml_settings).permit(
      :sso_url,
      :certificate,
      :sp_entity_id,
      :idp_entity_id,
      :metadata_url,
      role_mappings: {}
    )
  end
end
