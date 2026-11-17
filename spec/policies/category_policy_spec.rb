require 'rails_helper'

RSpec.describe CategoryPolicy, type: :policy do
  subject(:category_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:portal) { create(:portal, account: account) }
  let(:category) { create(:category, account: account, portal: portal, slug: 'test-category') }

  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.first } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.first } }

  permissions :index? do
    context 'when administrator' do
      it { expect(category_policy).to permit(administrator_context, category) }
    end

    context 'when agent' do
      it { expect(category_policy).to permit(agent_context, category) }
    end
  end

  permissions :update?, :show?, :edit?, :create?, :destroy? do
    context 'when administrator' do
      it { expect(category_policy).to permit(administrator_context, category) }
    end

    context 'when agent' do
      it { expect(category_policy).not_to permit(agent_context, category) }
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

    def allowed?(action)
      described_class.new(custom_role_agent_context, category).public_send("#{action}?")
    end

    context 'with knowledge_base_manage' do
      let(:permissions) { ['knowledge_base_manage'] }

      it 'allows management while keeping index readable' do
        %i[index show edit create update destroy reorder].each do |action|
          expect(allowed?(action)).to be(true), "expected #{action} to be allowed"
        end
      end
    end

    context 'without knowledge_base_manage' do
      let(:permissions) { ['contact_manage'] }

      it 'keeps index readable but denies management' do
        expect(allowed?(:index)).to be(true)
        %i[show edit create update destroy reorder].each do |action|
          expect(allowed?(action)).to be(false), "expected #{action} to be denied"
        end
      end
    end
  end
end
