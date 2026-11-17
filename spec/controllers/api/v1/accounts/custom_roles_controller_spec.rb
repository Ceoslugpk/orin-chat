require 'rails_helper'

RSpec.describe 'Custom Roles API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:role) { create(:custom_role, account: account, name: 'Support', permissions: ['conversation_manage']) }
  let(:url) { "/api/v1/accounts/#{account.id}/custom_roles" }
  let(:payload) { { name: 'Report viewers', description: 'Can review reports', permissions: ['report_manage'] } }

  shared_examples 'denied role-definition access' do
    [[:get, false], [:get, true], [:post, false], [:patch, true], [:delete, true]].each do |method, member|
      it "rejects #{method.to_s.upcase} #{member ? 'a role' : 'the role collection'}" do
        path = member ? "#{url}/#{role.id}" : url

        public_send(method, path, params: payload, headers: auth_headers, as: :json)

        expect(response).to have_http_status(:unauthorized)
        expect(role.reload.name).to eq('Support')
      end
    end
  end

  context 'without authentication' do
    let(:auth_headers) { {} }

    it_behaves_like 'denied role-definition access'
  end

  context 'with an ordinary agent' do
    let(:auth_headers) { agent.create_new_auth_token }

    it_behaves_like 'denied role-definition access'
  end

  context 'with an administrator of another account' do
    let(:other_administrator) { create(:user, account: create(:account), role: :administrator) }
    let(:auth_headers) { other_administrator.create_new_auth_token }

    it_behaves_like 'denied role-definition access'
  end

  context 'with an agent bot' do
    let(:bot) { create(:agent_bot, account: account) }
    let(:auth_headers) { { api_access_token: bot.access_token.token } }

    it_behaves_like 'denied role-definition access'
  end

  context 'with an account administrator' do
    let(:auth_headers) { administrator.create_new_auth_token }

    it 'returns only account-owned definitions in the dashboard array contract' do
      other = create(:custom_role, name: 'Foreign role')
      earlier = create(:custom_role, account: account, name: 'Analytics')

      get url, headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([earlier.id, role.id])
      expect(response.parsed_body.pluck('id')).not_to include(other.id)
    end

    it 'returns the role fields required by the edit form' do
      get "#{url}/#{role.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq(role.attributes.slice('id', 'name', 'description', 'permissions'))
    end

    it 'creates a definition and attributes its audit to the administrator' do
      expect do
        post url, params: payload, headers: auth_headers, as: :json
      end.to change(account.custom_roles, :count).by(1)

      expect(response).to have_http_status(:created)
      created = account.custom_roles.find(response.parsed_body['id'])
      expect(response.parsed_body).to include(payload.stringify_keys)
      expect(AuditLog.for_account(account).find_by(auditable: created, action: 'create').user).to eq(administrator)
    end

    it 'ignores a forged account owner on create' do
      other_account = create(:account)

      post url, params: payload.merge(account_id: other_account.id), headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(CustomRole.find(response.parsed_body['id']).account_id).to eq(account.id)
    end

    it 'updates the editable metadata without allowing account transfer' do
      other_account = create(:account)

      patch "#{url}/#{role.id}", params: payload.merge(account_id: other_account.id), headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(payload.stringify_keys)
      expect(role.reload.account_id).to eq(account.id)
    end

    it 'rejects privilege names outside the supported permission vocabulary' do
      expect do
        post url, params: payload.merge(permissions: ['administrator']), headers: auth_headers, as: :json
      end.not_to change(CustomRole, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['attributes']).to include('permissions')
    end

    it 'rejects missing or non-array permissions rather than silently accepting them' do
      [[], 'report_manage', { report_manage: true }].each do |permissions|
        post url, params: payload.merge(permissions: permissions), headers: auth_headers, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it 'does not mutate a definition or log a successful change on invalid update' do
      before_count = AuditLog.where(auditable: role).count

      patch "#{url}/#{role.id}", params: { name: 'Changed', permissions: ['administrator'] }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(role.reload.name).to eq('Support')
      expect(AuditLog.where(auditable: role).count).to eq(before_count)
    end

    it 'deletes an unreferenced definition and retains its audit history' do
      delete "#{url}/#{role.id}", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(CustomRole.exists?(role.id)).to be(false)
      expect(AuditLog.for_account(account).where(auditable_type: 'CustomRole', auditable_id: role.id).pluck(:action)).to include('destroy')
    end

    it 'rejects deletion of a referenced definition without changing the membership' do
      membership = create(:account_user, account: account, custom_role_id: role.id)

      delete "#{url}/#{role.id}", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to be_present
      expect(CustomRole.exists?(role.id)).to be(true)
      expect(membership.reload.custom_role_id).to eq(role.id)
    end

    [:get, :patch, :delete].each do |method|
      it "does not expose or mutate another account role through #{method.to_s.upcase}" do
        foreign_role = create(:custom_role, name: 'Foreign role')

        public_send(method, "#{url}/#{foreign_role.id}", params: payload, headers: auth_headers, as: :json)

        expect(response).to have_http_status(:not_found)
        expect(foreign_role.reload.name).to eq('Foreign role')
      end
    end

    it 'makes role-definition changes filterable in the audit API' do
      get "/api/v1/accounts/#{account.id}/audit_logs", params: { types: ['CustomRole'] }, headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['audit_logs'].pluck('auditable_type').uniq).to eq(['CustomRole'])
    end
  end
end
