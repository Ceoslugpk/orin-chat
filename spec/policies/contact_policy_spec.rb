# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContactPolicy, type: :policy do
  subject(:contact_policy) { described_class }

  let(:account) { create(:account) }

  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:contact) { create(:contact) }

  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.first } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.first } }

  permissions :index?, :show?, :update? do
    context 'when administrator' do
      it { expect(contact_policy).to permit(administrator_context, contact) }
    end

    context 'when agent' do
      it { expect(contact_policy).to permit(agent_context, contact) }
    end
  end

  permissions :create? do
    context 'when administrator' do
      it { expect(contact_policy).to permit(administrator_context, contact) }
    end

    context 'when agent' do
      it { expect(contact_policy).to permit(agent_context, contact) }
    end
  end

  describe 'custom role scopes' do
    let(:custom_role) { create(:custom_role, account: account, permissions: permissions) }
    let(:custom_role_agent_context) do
      { user: agent, account: account, account_user: agent.account_users.find_by!(account: account) }
    end
    let(:actions) do
      %i[index active search filter show contactable_inboxes create update avatar destroy_custom_attributes import export destroy]
    end

    before do
      account.enable_features!(:custom_roles)
      agent.account_users.find_by!(account: account).update!(custom_role: custom_role)
    end

    def allowed?(action)
      described_class.new(custom_role_agent_context, contact).public_send("#{action}?")
    end

    context 'with contact_manage' do
      let(:permissions) { ['contact_manage'] }

      it 'allows reads, mutations, import/export and destruction' do
        actions.each { |action| expect(allowed?(action)).to be(true), "expected #{action} to be allowed" }
      end
    end

    context 'without contact_manage' do
      let(:permissions) { ['report_manage'] }

      it 'denies every contact action' do
        actions.each { |action| expect(allowed?(action)).to be(false), "expected #{action} to be denied" }
      end
    end

    context 'when custom roles are disabled' do
      let(:permissions) { ['contact_manage'] }

      before { account.disable_features!(:custom_roles) }

      it 'keeps ordinary agent behavior' do
        expect(allowed?(:index)).to be(true)
        expect(allowed?(:update)).to be(true)
        expect(allowed?(:import)).to be(false)
        expect(allowed?(:export)).to be(false)
        expect(allowed?(:destroy)).to be(false)
      end
    end
  end
end
