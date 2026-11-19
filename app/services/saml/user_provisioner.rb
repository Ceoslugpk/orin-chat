class Saml::UserProvisioner
  def initialize(account:, auth:)
    @account = account
    @auth = auth
  end

  def perform
    email = auth.info&.email.to_s.downcase
    raise ArgumentError, 'SAML assertion is missing an email' if email.blank?

    user = find_or_create_user(email)
    ensure_account_membership(user)
    user
  end

  private

  attr_reader :account, :auth

  def find_or_create_user(email)
    user = User.from_email(email)
    return confirm_existing_user(user) if user.present?

    User.new(
      email: email,
      name: display_name(email),
      password: "#{Devise.friendly_token[0, 20]}aA1!"
    ).tap do |new_user|
      new_user.skip_confirmation!
      new_user.save!
    end
  end

  def confirm_existing_user(user)
    return user if user.confirmed_at.present?

    user.skip_confirmation!
    user.save!
    user
  end

  def display_name(email)
    name = [auth.info&.first_name, auth.info&.last_name].compact.join(' ').strip
    name.presence || email.split('@').first
  end

  def ensure_account_membership(user)
    account_user = AccountUser.find_or_initialize_by(account: account, user: user)
    role = mapped_role
    if account_user.new_record?
      account_user.role = role
      account_user.save!
    elsif role == 'administrator' && account_user.agent?
      account_user.update!(role: :administrator)
    end
  end

  def mapped_role
    groups = Array(raw_info['groups'] || raw_info['roles']).map(&:to_s)
    mappings = settings&.role_mappings || {}
    return 'administrator' if Array(mappings['administrator']).intersect?(groups)

    'agent'
  end

  def raw_info
    auth.extra&.raw_info || {}
  rescue StandardError
    {}
  end

  def settings
    @settings ||= AccountSamlSettings.find_by(account_id: account.id)
  end
end
