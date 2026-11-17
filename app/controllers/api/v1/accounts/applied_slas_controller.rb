class Api::V1::Accounts::AppliedSlasController < Api::V1::Accounts::BaseController
  include DateRangeHelper

  RESULTS_PER_PAGE = 25

  before_action :check_authorization
  before_action :ensure_sla_enabled
  before_action :set_applied_slas
  before_action :set_metrics, only: [:metrics]

  def index
    @applied_slas = @applied_slas.page(params[:page] || 1).per(RESULTS_PER_PAGE)
  end

  def metrics; end

  def download
    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = 'attachment; filename=sla_report.csv'
    render layout: false, template: 'api/v1/accounts/applied_slas/download', formats: [:csv]
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def ensure_sla_enabled
    head :not_found unless Current.account.feature_enabled?('sla')
  end

  def set_applied_slas
    @applied_slas = Current.account.applied_slas
                           .includes(:sla_events, :sla_policy, conversation: [:contact, :inbox, :team,
                                                                              { assignee: { avatar_attachment: [:blob] } }])
                           .filter_by_created_at(range)
                           .filter_by_sla_policy_id(params[:sla_policy_id])
                           .filter_by_assignee_id(params[:assigned_agent_id])
                           .filter_by_inbox_id(params[:inbox_id])
                           .filter_by_team_id(params[:team_id])
                           .filter_by_labels(label_list)
                           .order(created_at: :desc, id: :desc)
  end

  def set_metrics
    @total_applied_slas = @applied_slas.count
    @number_of_sla_misses = @applied_slas.where(sla_status: %i[missed active_with_misses]).count
    hit_count = @total_applied_slas - @number_of_sla_misses
    @hit_rate = if @total_applied_slas.zero?
                  '0%'
                else
                  ActiveSupport::NumberHelper.number_to_percentage(
                    hit_count * 100.0 / @total_applied_slas, precision: 2
                  )
                end
  end

  def label_list
    Array(params[:label_list]).flat_map { |label| label.to_s.split(',') }.map(&:strip).compact_blank
  end
end
