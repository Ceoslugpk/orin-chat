require 'rails_helper'

RSpec.describe 'SLA lifecycle', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, timezone: 'UTC') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:policy) do
    create(
      :sla_policy,
      account: account,
      name: 'Lifecycle SLA',
      first_response_time_threshold: 3600,
      next_response_time_threshold: 900,
      resolution_time_threshold: 7200
    )
  end

  before do
    account.enable_features!('sla')
    create(:inbox_member, inbox: inbox, user: agent)
    setting = agent.notification_settings.find_by(account_id: account.id)
    setting.selected_email_flags = [:email_sla_missed_first_response]
    setting.save!
  end

  it 'applies, breaches, completes, reopens and reports the policy' do
    rule = create(
      :automation_rule,
      account: account,
      actions: [{ action_name: 'add_sla', action_params: [policy.id] }]
    )

    AutomationRules::ActionService.new(rule, account, conversation).perform

    applied_sla = conversation.reload.applied_sla
    expect(applied_sla).to be_active
    expect(applied_sla.sla_frt_due_at).to be_present
    expect(applied_sla.sla_nrt_due_at).to be_nil

    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
        headers: administrator.create_new_auth_token,
        as: :json
    expect(JSON.parse(response.body, symbolize_names: true)[:applied_sla][:sla_name]).to eq('Lifecycle SLA')

    applied_sla.update!(sla_frt_due_at: 1.minute.ago)
    expect { Sla::BreachJob.perform_now(applied_sla.id, :frt) }.to change { agent.notifications.count }.by(1)
    expect(applied_sla.sla_events.pluck(:event_type)).to eq(['frt'])

    conversation.update!(status: :resolved)
    expect(applied_sla.reload).to be_missed

    conversation.update!(status: :open)
    expect(applied_sla.reload).to be_active_with_misses

    get "/api/v1/accounts/#{account.id}/applied_slas",
        headers: administrator.create_new_auth_token,
        as: :json
    report = JSON.parse(response.body, symbolize_names: true)
    expect(report[:meta][:count]).to eq(1)
    expect(report[:payload].first[:applied_sla][:sla_name]).to eq('Lifecycle SLA')
    expect(report[:payload].first[:sla_events].pluck(:event_type)).to include('frt')

    get "/api/v1/accounts/#{account.id}/applied_slas/metrics",
        headers: administrator.create_new_auth_token,
        as: :json
    expect(JSON.parse(response.body, symbolize_names: true)).to include(
      total_applied_slas: 1,
      number_of_sla_misses: 1,
      hit_rate: '0.00%'
    )
  end
end
