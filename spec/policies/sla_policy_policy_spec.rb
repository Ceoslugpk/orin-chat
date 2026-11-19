require 'rails_helper'

RSpec.describe SlaPolicyPolicy do
  let(:account) { create(:account) }
  let(:policy) { create(:sla_policy, account: account) }

  permissions :index?, :show?, :create?, :update?, :destroy? do
    it 'permits an account administrator' do
      membership = create(:account_user, account: account, role: :administrator)
      context = { user: membership.user, account: account, account_user: membership }

      expect(described_class).to permit(context, policy)
    end

    it 'denies ordinary account agents' do
      membership = create(:account_user, account: account, role: :agent)
      context = { user: membership.user, account: account, account_user: membership }

      expect(described_class).not_to permit(context, policy)
    end

    it 'fails closed without an account membership' do
      context = { user: nil, account: account, account_user: nil }

      expect(described_class).not_to permit(context, policy)
    end
  end
end
