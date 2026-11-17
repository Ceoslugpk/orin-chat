class Api::V1::Accounts::AuditLogsController < Api::V1::Accounts::BaseController
  SORT_DIRECTIONS = %w[asc desc].freeze
  AUDITABLE_TYPES = %w[Account AccountUser AutomationRule Conversation CustomRole Inbox InboxMember Macro Message Team TeamMember User Webhook].freeze
  MAX_SEARCH_LENGTH = 100

  before_action :check_authorization
  before_action :validate_filters

  def show
    @current_page = params[:page].present? ? params[:page].to_i : 1
    logs = filtered_logs
    @total_entries = logs.count
    @audit_logs = logs.order(created_at: sort_direction, id: sort_direction)
                      .includes(:auditable)
                      .offset((@current_page - 1) * AuditLog::PER_PAGE)
                      .limit(AuditLog::PER_PAGE)
  end

  private

  def check_authorization
    super(AuditLog)
  end

  def validate_filters
    return if valid_sort? && valid_page? && valid_types? && valid_time_range? && valid_search?

    render json: { error: 'Invalid audit log filters' }, status: :unprocessable_content
  end

  def valid_sort?
    params[:sort].blank? || SORT_DIRECTIONS.include?(params[:sort])
  end

  def valid_page?
    params[:page].blank? || params[:page].to_s.match?(/\A[1-9]\d*\z/)
  end

  def valid_types?
    types = params[:types]
    return true if types.blank?

    types.is_a?(Array) && types.all? { |type| AUDITABLE_TYPES.include?(type) }
  end

  def valid_time_range?
    since = params[:since]
    until_time = params[:until]
    return since.blank? && until_time.blank? if since.blank? || until_time.blank?
    return false unless timestamp_filter?(since) && timestamp_filter?(until_time)

    Time.zone.at(since.to_i) <= Time.zone.at(until_time.to_i)
  rescue RangeError, ArgumentError
    false
  end

  def timestamp_filter?(value)
    value.to_s.match?(/\A\d+\z/)
  end

  def valid_search?
    query = params[:q]
    return true if query.blank? || query.to_s.strip.blank?

    query.is_a?(String) && query.length <= MAX_SEARCH_LENGTH
  end

  def filtered_logs
    logs = AuditLog.for_account(Current.account)
    logs = logs.where(auditable_type: params[:types]) if params[:types].present?
    logs = logs.where(created_at: time_range) if params[:since].present?
    logs = logs.where(search_condition) if params[:q].to_s.strip.present?
    logs
  end

  def time_range
    Time.zone.at(params[:since].to_i)..Time.zone.at(params[:until].to_i)
  end

  def search_condition
    table = AuditLog.arel_table
    pattern = "%#{AuditLog.sanitize_sql_like(params[:q].to_s.strip)}%"
    table[:username].matches(pattern)
                    .or(table[:auditable_type].matches(pattern))
                    .or(table[:action].matches(pattern))
                    .or(table[:remote_address].matches(pattern))
                    .or(actor_search_condition(pattern))
  end

  def actor_search_condition(pattern)
    users = User.arel_table
    actor_ids = User.where(users[:name].matches(pattern).or(users[:email].matches(pattern))).select(:id)
    table = AuditLog.arel_table
    table[:user_type].eq(User.polymorphic_name).and(table[:user_id].in(actor_ids.arel))
  end

  def sort_direction
    params[:sort] == 'asc' ? :asc : :desc
  end
end
