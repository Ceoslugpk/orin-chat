require 'rails_helper'

RSpec.describe 'SLA Policies API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:policy) { create(:sla_policy, account: account, name: 'Gold') }
  let(:url) { "/api/v1/accounts/#{account.id}/sla_policies" }
  let(:payload) do
    {
      name: 'Silver',
      description: 'Answers within an hour',
      first_response_time_threshold: 3600,
      next_response_time_threshold: nil,
      resolution_time_threshold: 7200,
      only_during_business_hours: true
    }
  end

  shared_examples 'denied SLA policy access' do
    [[:get, false], [:get, true], [:post, false], [:patch, true], [:delete, true]].each do |method, member|
      it "rejects #{method.to_s.upcase} #{member ? 'a policy' : 'the policy collection'}" do
        path = member ? "#{url}/#{policy.id}" : url

        public_send(method, path, params: payload, headers: auth_headers, as: :json)

        expect(response).to have_http_status(:unauthorized)
        expect(policy.reload.name).to eq('Gold')
      end
    end
  end

  context 'without authentication' do
    let(:auth_headers) { {} }

    it_behaves_like 'denied SLA policy access'
  end

  context 'with an ordinary agent' do
    let(:auth_headers) { agent.create_new_auth_token }

    it_behaves_like 'denied SLA policy access'
  end

  context 'with an administrator of another account' do
    let(:other_administrator) { create(:user, account: create(:account), role: :administrator) }
    let(:auth_headers) { other_administrator.create_new_auth_token }

    it_behaves_like 'denied SLA policy access'
  end

  context 'with an agent bot' do
    let(:bot) { create(:agent_bot, account: account) }
    let(:auth_headers) { { api_access_token: bot.access_token.token } }

    it_behaves_like 'denied SLA policy access'
  end

  context 'with an account administrator' do
    let(:auth_headers) { administrator.create_new_auth_token }

    it 'returns only account-owned policies ordered by name' do
      create(:sla_policy, name: 'Foreign policy')
      create(:sla_policy, account: account, name: 'Bronze')

      get url, headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('name')).to eq(%w[Bronze Gold])
    end

    it 'returns the fields required by the dashboard form' do
      get "#{url}/#{policy.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to eq(
        policy.attributes.slice(
          'id',
          'name',
          'description',
          'first_response_time_threshold',
          'next_response_time_threshold',
          'resolution_time_threshold',
          'only_during_business_hours'
        )
      )
    end

    it 'creates a policy and ignores a forged account owner' do
      other_account = create(:account)

      expect do
        post url, params: payload.merge(account_id: other_account.id), headers: auth_headers, as: :json
      end.to change(account.sla_policies, :count).by(1)

      expect(response).to have_http_status(:created)
      created = account.sla_policies.find(response.parsed_body['payload']['id'])
      expect(created.attributes.slice(*payload.keys.map(&:to_s))).to eq(payload.stringify_keys)
    end

    it 'rejects a policy without any threshold' do
      expect do
        post url,
             params: payload.merge(
               first_response_time_threshold: nil,
               next_response_time_threshold: nil,
               resolution_time_threshold: nil
             ),
             headers: auth_headers, as: :json
      end.not_to change(SlaPolicy, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['attributes']).to include('base')
    end

    it 'updates the policy without allowing account transfer' do
      patch "#{url}/#{policy.id}", params: { name: 'Platinum', account_id: create(:account).id },
                                   headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(policy.reload.name).to eq('Platinum')
      expect(policy.account_id).to eq(account.id)
    end

    it 'does not expose a policy from another account' do
      foreign_policy = create(:sla_policy)

      get "#{url}/#{foreign_policy.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'deletes the policy and clears linked conversations' do
      conversation = create(:conversation, account: account, sla_policy: policy)

      delete "#{url}/#{policy.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(SlaPolicy.exists?(policy.id)).to be(false)
      expect(conversation.reload.sla_policy_id).to be_nil
    end
  end
end
