class Api::V1::AuthController < Api::BaseController
  skip_before_action :authenticate_user!, only: :saml_login

  def saml_login
    account = saml_account
    return redirect_to "#{frontend_url}/app/login?error=saml-not-enabled", allow_other_host: true if account.blank?

    session[:saml_account_id] = account.id
    session[:saml_redirect_url] = params[:redirect_url].presence
    session[:saml_target] = params[:target].presence

    redirect_to "/omniauth/saml?account_id=#{account.id}"
  end

  private

  def saml_account
    if params[:sso_account_id].present?
      requested_account = Account.find_by(id: params[:sso_account_id])
      return requested_account if saml_enabled?(requested_account)
    end

    user = User.from_email(params[:email].to_s.strip)
    return if user.blank?

    user.accounts.find { |candidate| saml_enabled?(candidate) }
  end

  def saml_enabled?(account)
    return false if account.blank?

    account.feature_enabled?('saml') &&
      AccountSamlSettings.find_by(account_id: account.id)&.configured?
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
