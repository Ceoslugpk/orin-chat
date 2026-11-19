require 'rails_helper'

RSpec.describe 'Audit Logs API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/audit_logs" }

  describe 'GET /api/v1/accounts/{account.id}/audit_logs' do
    it 'returns unauthorized for unauthenticated requests' do
      get url
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not allow agents to read the audit log' do
      get url, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not allow administrators from another account to read the log' do
      other_administrator = create(:user, account: create(:account), role: :administrator)

      get url, headers: other_administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not allow agent bots to read the log' do
      bot = create(:agent_bot, account: account)

      get url, headers: { api_access_token: bot.access_token.token }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    context 'when an administrator requests the log' do
      let!(:inbox) { create(:inbox, account: account) }

      before do
        create(:webhook, account: account)
        create(:inbox, account: create(:account))
      end

      it 'returns only this account activity' do
        get url, headers: administrator.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['audit_logs'].pluck('auditable_type')).to include('Inbox', 'Webhook')
        expect(body['audit_logs'].pluck('auditable_id')).to include(inbox.id)
        expect(body['audit_logs'].pluck('associated_id').uniq.compact).to eq([account.id])
        expect(body['audit_logs'].first['created_at']).to be_a(Integer)
      end

      it 'returns pagination metadata' do
        get url, headers: administrator.create_new_auth_token, as: :json

        expect(response.parsed_body.slice('current_page', 'per_page', 'total_entries')).to eq(
          'current_page' => 1, 'per_page' => AuditLog::PER_PAGE, 'total_entries' => AuditLog.for_account(account).count
        )
      end

      %w[name email].each do |attribute|
        it "searches by the acting agent #{attribute}" do
          AuditLog.as_user(administrator) { inbox.update!(name: 'Updated support inbox') }
          log = AuditLog.for_account(account).find_by(auditable: inbox, action: 'update')

          get url, params: { q: administrator.public_send(attribute) }, headers: administrator.create_new_auth_token

          expect(response).to have_http_status(:success)
          expect(response.parsed_body['audit_logs'].pluck('id')).to include(log.id)
        end
      end

      it 'filters by event type' do
        get url, params: { types: ['Webhook'] }, headers: administrator.create_new_auth_token

        expect(response.parsed_body['audit_logs'].pluck('auditable_type').uniq).to eq(['Webhook'])
      end

      it 'filters by time range' do
        old_log = AuditLog.for_account(account).find_by(auditable: inbox)
        old_log.update!(created_at: 10.days.ago)

        get url, params: { since: 2.days.ago.to_i, until: Time.current.to_i }, headers: administrator.create_new_auth_token

        expect(response.parsed_body['audit_logs'].pluck('id')).not_to include(old_log.id)
      end

      it 'sorts oldest first when asked' do
        get url, params: { sort: 'asc' }, headers: administrator.create_new_auth_token

        ids = response.parsed_body['audit_logs'].pluck('id')
        expect(ids).to eq(ids.sort)
      end

      it 'rejects an unknown sort direction' do
        get url, params: { sort: 'sideways' }, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects event types that the audit log does not support' do
        get url, params: { types: ['PasswordReset'] }, headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects incomplete and reversed time ranges' do
        headers = administrator.create_new_auth_token

        get url, params: { since: 1 }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)

        get url, params: { since: 2, until: 1 }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects invalid page numbers and oversized search terms' do
        headers = administrator.create_new_auth_token

        get url, params: { page: -1 }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)

        get url, params: { q: 'a' * (Api::V1::Accounts::AuditLogsController::MAX_SEARCH_LENGTH + 1) }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'treats a whitespace-only search as no search filter' do
        get url, params: { q: '   ' }, headers: administrator.create_new_auth_token

        expect(response.parsed_body['total_entries']).to eq(AuditLog.for_account(account).count)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/audit_logs/download' do
    it 'exports filtered audit logs as CSV for administrators only' do
      inbox = create(:inbox, account: account)
      inbox.update!(name: 'Exported Inbox')

      get "#{url}/download", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      get "#{url}/download", headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.body).to include('Record Type', 'Inbox')
      expect(response.body).to include(inbox.id.to_s)
    end

    it 'applies the same filters as the list endpoint' do
      inbox = create(:inbox, account: account)
      inbox.update!(name: 'Filtered Inbox')

      get "#{url}/download", headers: administrator.create_new_auth_token,
                             params: { q: 'NoMatchingAuditEvent' }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Filtered Inbox')
    end
  end
end
