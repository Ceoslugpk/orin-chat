require 'rails_helper'

RSpec.describe AuditLog do
  let(:account) { create(:account) }

  describe 'audited models' do
    it 'records inbox changes against the inbox account' do
      inbox = create(:inbox, account: account)

      log = described_class.for_account(account).find_by(auditable: inbox, action: 'create')
      expect(log).to be_present
      expect(log.associated).to eq(account)
    end

    it 'records account updates on the account itself' do
      account.update!(name: 'Renamed')

      log = described_class.for_account(account).find_by(auditable: account, action: 'update')
      expect(log.audited_changes['name']).to eq([account.name_previously_was, 'Renamed'])
    end

    it 'does not record webhook secrets' do
      webhook = create(:webhook, account: account)

      log = described_class.find_by(auditable: webhook, action: 'create')
      expect(log.audited_changes).not_to have_key('secret')
    end

    it 'does not record agent activity timestamps' do
      account_user = create(:account_user, account: account)

      expect { account_user.update!(active_at: Time.current) }.not_to change(described_class, :count)
      expect { account_user.update!(role: :administrator) }.to change(described_class, :count).by(1)
    end

    it 'records permission-relevant membership changes, not the unmodelled capacity column' do
      custom_role = create(:custom_role, account: account)

      expect { create(:account_user, account: account, custom_role: custom_role) }
        .to change { described_class.where(auditable_type: 'AccountUser').count }.by(1)

      log = described_class.order(:id).find_by(auditable_type: 'AccountUser', action: 'create')
      expect(log.audited_changes).to include('custom_role_id', 'auto_offline')
      expect(log.audited_changes).not_to have_key('agent_capacity_policy_id')
    end

    it 'keeps the removed account agent identity in the deletion audit' do
      membership = create(:account_user, account: account)
      user_id = membership.user_id

      membership.destroy!

      log = described_class.for_account(account).find_by(auditable_type: 'AccountUser', auditable_id: membership.id, action: 'destroy')
      expect(log.audited_changes['user_id']).to eq(user_id)
      expect(log.auditable).to be_nil
    end

    it 'records inbox membership against the inbox account' do
      member = create(:inbox_member, inbox: create(:inbox, account: account))

      expect(described_class.for_account(account).find_by(auditable: member, action: 'create')).to be_present
    end
  end

  describe '.for_account' do
    it 'excludes activity from other accounts' do
      create(:inbox, account: create(:account))

      expect(described_class.for_account(account).where(auditable_type: 'Inbox')).to be_empty
    end
  end

  describe '.with_context' do
    it 'attributes audits written outside a request to the given user and IP' do
      user = create(:user, account: account)

      described_class.with_context(user: user, ip: '203.0.113.7') do
        described_class.record!(auditable: account, account: account, action: 'update')
      end

      log = described_class.last
      expect(log.user).to eq(user)
      expect(log.remote_address).to eq('203.0.113.7')
    end
  end

  describe 'context cleanup' do
    it 'restores the remote address after an audited operation fails' do
      previous_ip = Audited.store[:current_remote_address]

      expect do
        described_class.with_context(user: nil, ip: '203.0.113.7') { raise ArgumentError, 'operation failed' }
      end.to raise_error(ArgumentError, 'operation failed')

      expect(Audited.store[:current_remote_address]).to eq(previous_ip)
    end
  end

  describe '#location' do
    it 'joins the city and country when present' do
      expect(described_class.new(city: 'Lahore', country: 'Pakistan').location).to eq('Lahore, Pakistan')
      expect(described_class.new.location).to be_nil
    end
  end
end
