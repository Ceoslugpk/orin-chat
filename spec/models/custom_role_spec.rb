require 'rails_helper'

RSpec.describe CustomRole do
  let(:account) { create(:account) }
  let(:role) { build(:custom_role, account: account, name: 'Report viewers', permissions: ['report_manage']) }

  describe 'validation' do
    it 'accepts the permission vocabulary exposed by the MIT dashboard' do
      role.permissions = described_class::PERMISSIONS

      expect(role).to be_valid
    end

    it 'normalizes surrounding name whitespace' do
      role.name = '  Report viewers  '

      role.save!

      expect(role.reload.name).to eq('Report viewers')
    end

    it 'requires a name and description' do
      role.assign_attributes(name: ' ', description: '')

      expect(role).not_to be_valid
      expect(role.errors.attribute_names).to include(:name, :description)
    end

    it 'rejects role names that are too short or too long' do
      ['A', 'a' * 101].each do |name|
        role.name = name
        expect(role).not_to be_valid
        expect(role.errors[:name]).to be_present
      end
    end

    it 'rejects an oversized description' do
      role.description = 'a' * 1_001

      expect(role).not_to be_valid
      expect(role.errors[:description]).to be_present
    end

    it 'identifies definitions by ID without imposing a new naming constraint on legacy data' do
      existing = create(:custom_role, account: account, name: role.name, permissions: ['contact_manage'])

      role.save!

      expect(role.id).not_to eq(existing.id)
      expect(role.permissions).not_to eq(existing.permissions)
    end

    it 'allows the same role name in another account' do
      create(:custom_role, name: role.name)

      expect(role).to be_valid
    end

    [nil, [], ['administrator'], %w[report_manage report_manage], ['unknown'], 'report_manage'].each do |permissions|
      it "rejects unsupported permission data #{permissions.inspect}" do
        role.permissions = permissions

        expect(role).not_to be_valid
        expect(role.errors[:permissions]).to be_present
      end
    end
  end

  describe 'lifecycle and auditing' do
    it 'records definition changes against the owning account' do
      actor = create(:user, account: account, role: :administrator)

      AuditLog.as_user(actor) do
        role.save!
        role.update!(permissions: ['contact_manage'])
        role.destroy!
      end

      logs = AuditLog.for_account(account).where(auditable_type: 'CustomRole', auditable_id: role.id).order(:id)
      expect(logs.pluck(:action)).to eq(%w[create update destroy])
      expect(logs.pluck(:user_id).uniq).to eq([actor.id])
      expect(logs.second.audited_changes['permissions']).to eq([['report_manage'], ['contact_manage']])
    end

    it 'does not log rejected validation as a change' do
      role.save!

      expect { role.update(permissions: ['administrator']) }.not_to change(AuditLog, :count)
    end

    it 'does not silently delete a role still referenced by a membership' do
      role.save!
      membership = create(:account_user, account: account, custom_role_id: role.id)

      expect { expect(role.destroy).to be(false) }.not_to change(AuditLog, :count)
      expect(role.errors[:base]).to be_present
      expect(membership.reload.custom_role_id).to eq(role.id)
      expect(described_class.exists?(role.id)).to be(true)
    end

    it 'cleans role definitions when their whole account is deleted' do
      role.save!
      create(:account_user, account: account, custom_role_id: role.id)

      account.destroy!

      expect(described_class.exists?(role.id)).to be(false)
    end
  end

  describe 'permission cache invalidation' do
    let(:invalidator) do
      instance_double(
        Conversations::UnreadCounts::FilteredCountInvalidator,
        users_visibility_changed!: true,
        user_visibility_changed!: true
      )
    end

    before do
      allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).and_return(invalidator)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'invalidates linked members when permissions change' do
      account.enable_features!(:custom_roles)
      role.save!
      membership = create(:account_user, account: account, custom_role_id: role.id)

      role.update!(permissions: ['contact_manage'])

      expect(invalidator).to have_received(:users_visibility_changed!).with(user_ids: [membership.user_id])
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.permissions_changed',
        kind_of(Time),
        account: account,
        user_ids: [membership.user_id]
      )
    end

    it 'does not invalidate members for metadata-only changes' do
      role.save!
      create(:account_user, account: account, custom_role_id: role.id)

      role.update!(description: 'Updated description')

      expect(invalidator).not_to have_received(:users_visibility_changed!)
    end
  end
end
