require 'rails_helper'

RSpec.describe 'Agent Capacity Policies API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:policy) { create(:agent_capacity_policy, account: account) }

  before { account.enable_features!('advanced_assignment') }

  describe 'GET /api/v1/accounts/{account.id}/agent_capacity_policies' do
    it 'returns unauthorized when unauthenticated' do
      get "/api/v1/accounts/#{account.id}/agent_capacity_policies"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies agents' do
      get "/api/v1/accounts/#{account.id}/agent_capacity_policies",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found when advanced assignment is disabled' do
      account.disable_features!('advanced_assignment')

      get "/api/v1/accounts/#{account.id}/agent_capacity_policies",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'lists capacity policies with users and inbox limits' do
      create(:inbox_member, inbox: inbox, user: agent)
      agent.account_users.find_by!(account: account).update!(agent_capacity_policy: policy)
      create(:inbox_capacity_limit, agent_capacity_policy: policy, inbox: inbox, conversation_limit: 5)

      get "/api/v1/accounts/#{account.id}/agent_capacity_policies",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.length).to eq(1)
      expect(body.first).to include(
        'id' => policy.id,
        'name' => policy.name,
        'assigned_agent_count' => 1
      )
      expect(body.first['users'].first).to include('id' => agent.id, 'email' => agent.email)
      expect(body.first['inbox_capacity_limits'].first).to include(
        'inbox_id' => inbox.id,
        'conversation_limit' => 5
      )
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/agent_capacity_policies' do
    it 'creates a policy and normalizes exclusion rules' do
      expect do
        post "/api/v1/accounts/#{account.id}/agent_capacity_policies",
             headers: administrator.create_new_auth_token,
             params: {
               agent_capacity_policy: {
                 name: 'Capacity Policy',
                 description: 'Limits work in progress',
                 exclusion_rules: { excluded_labels: ['vip'], exclude_older_than_hours: '24' }
               }
             },
             as: :json
      end.to change(AgentCapacityPolicy, :count).by(1)

      expect(response).to have_http_status(:created)
      created = AgentCapacityPolicy.last
      expect(created.exclusion_rules).to eq(
        'excluded_labels' => ['vip'],
        'exclude_older_than_hours' => 24
      )
    end

    it 'rejects duplicate names within the account' do
      policy
      post "/api/v1/accounts/#{account.id}/agent_capacity_policies",
           headers: administrator.create_new_auth_token,
           params: { agent_capacity_policy: { name: policy.name } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/agent_capacity_policies/:id' do
    it 'updates the policy' do
      put "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}",
          headers: administrator.create_new_auth_token,
          params: { agent_capacity_policy: { name: 'Updated Capacity', description: 'Updated' } },
          as: :json

      expect(response).to have_http_status(:success)
      expect(policy.reload.name).to eq('Updated Capacity')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/agent_capacity_policies/:id' do
    it 'deletes the policy and unlinks agents' do
      agent.account_users.find_by!(account: account).update!(agent_capacity_policy: policy)

      expect do
        delete "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}",
               headers: administrator.create_new_auth_token,
               as: :json
      end.to change(AgentCapacityPolicy, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(agent.account_users.find_by!(account: account).agent_capacity_policy_id).to be_nil
    end
  end

  describe 'nested users' do
    it 'adds, lists and removes agents' do
      post "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/users",
           headers: administrator.create_new_auth_token,
           params: { user_id: agent.id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(agent.account_users.find_by!(account: account).agent_capacity_policy).to eq(policy)

      get "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/users",
          headers: administrator.create_new_auth_token,
          as: :json
      expect(response.parsed_body.pluck('id')).to eq([agent.id])

      delete "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/users/#{agent.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(agent.account_users.find_by!(account: account).agent_capacity_policy_id).to be_nil
    end

    it 'moves an agent from another capacity policy' do
      other_policy = create(:agent_capacity_policy, account: account)
      agent.account_users.find_by!(account: account).update!(agent_capacity_policy: other_policy)

      post "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/users",
           headers: administrator.create_new_auth_token,
           params: { user_id: agent.id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(agent.account_users.find_by!(account: account).agent_capacity_policy).to eq(policy)
    end
  end

  describe 'nested inbox limits' do
    it 'creates, updates and deletes a limit' do
      post "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/inbox_limits",
           headers: administrator.create_new_auth_token,
           params: { inbox_id: inbox.id, conversation_limit: 4 },
           as: :json

      expect(response).to have_http_status(:created)
      limit = policy.inbox_capacity_limits.find_by!(inbox: inbox)
      expect(limit.conversation_limit).to eq(4)

      put "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/inbox_limits/#{limit.id}",
          headers: administrator.create_new_auth_token,
          params: { conversation_limit: 8 },
          as: :json

      expect(response).to have_http_status(:success)
      expect(limit.reload.conversation_limit).to eq(8)

      delete "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/inbox_limits/#{limit.id}",
             headers: administrator.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(policy.inbox_capacity_limits.reload).to be_empty
    end

    it 'rejects a non-positive limit' do
      post "/api/v1/accounts/#{account.id}/agent_capacity_policies/#{policy.id}/inbox_limits",
           headers: administrator.create_new_auth_token,
           params: { inbox_id: inbox.id, conversation_limit: 0 },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
