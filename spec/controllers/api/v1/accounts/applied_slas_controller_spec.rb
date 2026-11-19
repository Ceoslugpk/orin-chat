require 'rails_helper'

RSpec.describe 'Applied SLAs API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:sla_policy) { create(:sla_policy, account: account, first_response_time_threshold: 3600) }

  def create_applied_sla(status:, conversation: nil, policy: sla_policy, inbox: self.inbox)
    conversation ||= create(:conversation, account: account, inbox: inbox)
    create(:applied_sla, account: account, conversation: conversation, sla_policy: policy,
                         sla_status: status, completed_at: Time.current,
                         sla_frt_due_at: 1.hour.from_now)
  end

  describe 'GET /api/v1/accounts/{account.id}/applied_slas' do
    it 'returns unauthorized when unauthenticated' do
      get "/api/v1/accounts/#{account.id}/applied_slas"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies agents without report permission' do
      account.enable_features!('sla')

      get "/api/v1/accounts/#{account.id}/applied_slas",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found while SLA tracking is disabled' do
      get "/api/v1/accounts/#{account.id}/applied_slas",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns applied SLAs with conversation and event details' do
      account.enable_features!('sla')
      hit = create_applied_sla(status: 'hit')
      missed = create_applied_sla(status: 'missed')
      create(:sla_event, applied_sla: missed, conversation: missed.conversation,
                         account: account, inbox: missed.conversation.inbox, sla_policy: sla_policy)

      get "/api/v1/accounts/#{account.id}/applied_slas",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:meta]).to eq({ count: 2, current_page: 1 })

      report = body[:payload].find { |item| item[:applied_sla][:id] == missed.id }
      expect(report[:applied_sla]).to include(
        sla_name: sla_policy.name,
        sla_status: 'missed',
        conversation_id: missed.conversation_id,
        sla_frt_due_at: missed.sla_frt_due_at.to_i
      )
      expect(report[:conversation]).to include(
        id: missed.conversation.display_id,
        uuid: missed.conversation.uuid,
        labels: missed.conversation.cached_label_list
      )
      expect(report[:conversation][:contact][:name]).to eq(missed.conversation.contact.name)
      expect(report[:sla_events].pluck(:event_type)).to eq(['frt'])
      expect(body[:payload].find { |item| item[:applied_sla][:id] == hit.id }).to be_present
    end

    it 'filters by policy, inbox, assignee and labels' do
      account.enable_features!('sla')
      other_policy = create(:sla_policy, account: account, name: 'other_sla')
      other_inbox = create(:inbox, account: account)
      matching = create_applied_sla(status: 'hit')
      matching.conversation.update!(assignee: agent, label_list: ['billing'])
      create_applied_sla(status: 'hit', inbox: other_inbox, policy: other_policy)

      get "/api/v1/accounts/#{account.id}/applied_slas",
          headers: administrator.create_new_auth_token,
          params: {
            sla_policy_id: sla_policy.id,
            inbox_id: inbox.id,
            assigned_agent_id: agent.id,
            label_list: ['billing']
          },
          as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:meta][:count]).to eq(1)
      expect(body[:payload].first[:applied_sla][:id]).to eq(matching.id)
    end

    it 'filters by creation date range' do
      account.enable_features!('sla')
      old_sla = create_applied_sla(status: 'hit')
      old_sla.update_column(:created_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      create_applied_sla(status: 'hit')

      get "/api/v1/accounts/#{account.id}/applied_slas",
          headers: administrator.create_new_auth_token,
          params: { since: 1.day.ago.to_i.to_s, until: 1.minute.from_now.to_i.to_s },
          as: :json

      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:meta][:count]).to eq(1)
      expect(body[:payload].first[:applied_sla][:id]).not_to eq(old_sla.id)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/applied_slas/metrics' do
    it 'returns totals, misses and hit rate for the filtered set' do
      account.enable_features!('sla')
      create_applied_sla(status: 'hit')
      create_applied_sla(status: 'missed')

      get "/api/v1/accounts/#{account.id}/applied_slas/metrics",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body, symbolize_names: true)).to eq(
        total_applied_slas: 2,
        number_of_sla_misses: 1,
        hit_rate: '50.00%'
      )
    end

    it 'returns zeroed metrics when nothing matches' do
      account.enable_features!('sla')

      get "/api/v1/accounts/#{account.id}/applied_slas/metrics",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(JSON.parse(response.body, symbolize_names: true)).to eq(
        total_applied_slas: 0,
        number_of_sla_misses: 0,
        hit_rate: '0%'
      )
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/applied_slas/download' do
    it 'returns a CSV with the filtered applied SLAs' do
      account.enable_features!('sla')
      applied_sla = create_applied_sla(status: 'missed')
      create(:sla_event, applied_sla: applied_sla, conversation: applied_sla.conversation,
                         account: account, inbox: applied_sla.conversation.inbox, sla_policy: sla_policy)

      get "/api/v1/accounts/#{account.id}/applied_slas/download",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.body).to include('Conversation ID', 'SLA Policy', 'Breached Events')
      expect(response.body).to include(applied_sla.conversation.display_id.to_s, sla_policy.name, 'FRT')
    end
  end
end
