require 'rails_helper'

RSpec.describe CustomRolePolicy do
  let(:account) { create(:account) }
  let(:role) { create(:custom_role, account: account) }

  permissions :index?, :show?, :create?, :update?, :destroy? do
    it 'permits an account administrator' do
      membership = create(:account_user, account: account, role: :administrator)
      context = { user: membership.user, account: account, account_user: membership }

      expect(described_class).to permit(context, role)
    end

    it 'denies ordinary account agents' do
      membership = create(:account_user, account: account, role: :agent)
      context = { user: membership.user, account: account, account_user: membership }

      expect(described_class).not_to permit(context, role)
    end

    it 'fails closed without an account membership' do
      context = { user: nil, account: account, account_user: nil }

      expect(described_class).not_to permit(context, role)
    end
  end
end
