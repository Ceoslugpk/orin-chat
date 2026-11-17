# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportPolicy, type: :policy do
  subject(:report_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:report) { :report }

  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.first } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.first } }

  permissions :view? do
    context 'when administrator' do
      it { expect(report_policy).to permit(administrator_context, report) }
    end

    context 'when agent' do
      it { expect(report_policy).not_to permit(agent_context, report) }
    end
  end

  describe 'custom role scopes' do
    let(:custom_role) { create(:custom_role, account: account, permissions: permissions) }
    let(:custom_role_agent_context) do
      { user: agent, account: account, account_user: agent.account_users.find_by!(account: account) }
    end

    before do
      account.enable_features!(:custom_roles)
      agent.account_users.find_by!(account: account).update!(custom_role: custom_role)
    end

    def allowed?
      described_class.new(custom_role_agent_context, report).view?
    end

    context 'with report_manage' do
      let(:permissions) { ['report_manage'] }

      it 'allows reports' do
        expect(allowed?).to be(true)
      end
    end

    context 'without report_manage' do
      let(:permissions) { ['contact_manage'] }

      it 'denies reports' do
        expect(allowed?).to be(false)
      end
    end

    context 'when custom roles are disabled' do
      let(:permissions) { ['report_manage'] }

      before { account.disable_features!(:custom_roles) }

      it 'keeps the ordinary agent restriction' do
        expect(allowed?).to be(false)
      end
    end
  end
end
