# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountUser do
  include ActiveJob::TestHelper

  let!(:account_user) { create(:account_user) }
  let!(:inbox) { create(:inbox, account: account_user.account) }

  describe 'notification_settings' do
    it 'gets created with the right default settings' do
      expect(account_user.user.notification_settings).not_to be_nil

      expect(account_user.user.notification_settings.first.email_conversation_creation?).to be(false)
      expect(account_user.user.notification_settings.first.email_conversation_assignment?).to be(true)
    end
  end

  describe 'work preferences' do
    it 'allows turning off one of conversations or calls' do
      expect(account_user.update(accepts_calls: false)).to be(true)
    end

    it 'rejects turning off both conversations and calls' do
      expect(account_user.update(accepts_conversations: false, accepts_calls: false)).to be(false)
      expect(account_user.errors[:base]).to include('Receive conversations or Receive voice calls must stay on')
    end
  end

  describe 'permissions' do
    it 'returns the right permissions' do
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'returns the right permissions for administrator' do
      account_user.administrator!
      expect(account_user.permissions).to eq(['administrator'])
    end
  end

  describe 'effective custom role permissions' do
    let(:custom_role) { create(:custom_role, account: account_user.account, permissions: ['report_manage']) }

    it 'keeps the ordinary agent permission while custom roles are disabled' do
      account_user.update!(custom_role: custom_role)

      expect(account_user.reload.permissions).to eq(['agent'])
    end

    it 'returns the linked definition permissions when custom roles are enabled' do
      account_user.account.enable_features!(:custom_roles)
      account_user.update!(custom_role: custom_role)

      expect(account_user.reload.permissions).to eq(['report_manage'])
    end

    it 'resolves the current definition and account state on each call' do
      account_user.account.enable_features!(:custom_roles)
      account_user.update!(custom_role: custom_role)

      expect(account_user.permissions).to eq(['report_manage'])

      custom_role.update!(permissions: ['contact_manage'])
      expect(account_user.permissions).to eq(['contact_manage'])

      account_user.account.disable_features!(:custom_roles)
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'keeps the administrator permission when custom roles are enabled' do
      account_user.account.enable_features!(:custom_roles)
      account_user.update!(role: :administrator)

      expect(account_user.reload.permissions).to eq(['administrator'])
    end

    it 'returns the ordinary agent permission when no definition is linked' do
      account_user.account.enable_features!(:custom_roles)

      expect(account_user.reload.permissions).to eq(['agent'])
    end

    it 'fails closed when the linked definition no longer exists' do
      removed_id = custom_role.id
      custom_role.delete
      account_user.custom_role_id = removed_id
      account_user.save!(validate: false)
      account_user.account.enable_features!(:custom_roles)

      expect(account_user.reload.permissions).to eq([])
    end

    it 'fails closed for a foreign definition stored outside model validation' do
      foreign_role = create(:custom_role)
      account_user.custom_role_id = foreign_role.id
      account_user.save!(validate: false)
      account_user.account.enable_features!(:custom_roles)

      expect(account_user.reload.permissions).to eq([])
    end

    it 'does not grant an administrator permission stored in a legacy definition' do
      custom_role.permissions = ['administrator']
      custom_role.save!(validate: false)
      account_user.update!(custom_role: custom_role)
      account_user.account.enable_features!(:custom_roles)

      expect(account_user.reload.permissions).to eq([])
    end
  end

  describe 'custom role links' do
    let(:custom_role) { create(:custom_role, account: account_user.account, permissions: ['report_manage']) }

    it 'links a same-account definition without activating its effective permissions' do
      account_user.update!(custom_role: custom_role)

      expect(account_user.reload.custom_role).to eq(custom_role)
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'rejects a foreign account definition' do
      account_user.custom_role = create(:custom_role)

      expect(account_user).not_to be_valid
      expect(account_user.errors[:custom_role]).to include('must belong to the membership account')
    end

    it 'rejects a missing definition' do
      removed_id = custom_role.id
      custom_role.delete
      account_user.custom_role_id = removed_id

      expect(account_user).not_to be_valid
      expect(account_user.errors[:custom_role]).to include('does not exist')
    end

    it 'does not combine an administrator role with a custom definition' do
      account_user.assign_attributes(role: :administrator, custom_role: custom_role)

      expect(account_user).not_to be_valid
      expect(account_user.errors[:custom_role]).to be_present
    end

    it 'requires explicit clearing before promotion of a linked agent' do
      account_user.update!(custom_role: custom_role)

      expect(account_user.update(role: :administrator)).to be(false)
      expect(account_user.reload.role).to eq('agent')
    end

    it 'allows an explicit clear and promotion in one write' do
      account_user.update!(custom_role: custom_role)

      account_user.update!(custom_role: nil, role: :administrator)

      expect(account_user.reload.custom_role_id).to be_nil
      expect(account_user.permissions).to eq(['administrator'])
    end

    it 'rejects moving a linked membership to another account' do
      account_user.update!(custom_role: custom_role)
      original_account_id = account_user.account_id

      expect(account_user.update(account: create(:account))).to be(false)
      expect(account_user.reload.account_id).to eq(original_account_id)
    end

    it 'validates a new membership with a custom reference' do
      membership = build(:account_user, account: account_user.account, custom_role: create(:custom_role))

      expect(membership).not_to be_valid
      expect(membership.errors[:custom_role]).to be_present
    end

    it 'saves a new same-account definition linked to an existing agent' do
      definition = build(:custom_role, account: account_user.account)

      account_user.update!(custom_role: definition)

      expect(definition).to be_persisted
      expect(account_user.reload.custom_role_id).to eq(definition.id)
    end

    it 'does not autosave a foreign new definition through the association' do
      account_user.custom_role = build(:custom_role)

      expect { account_user.save }.not_to change(CustomRole, :count)
      expect(account_user.errors[:custom_role]).to be_present
    end

    it 'does not equate two different unsaved owning accounts' do
      membership = build(:account_user, account: build(:account), custom_role: build(:custom_role, account: build(:account)))

      expect(membership).not_to be_valid
      expect(membership.errors[:custom_role]).to include('must belong to the membership account')
    end

    it 'preserves availability updates on an unchanged legacy dangling reference' do
      removed_id = custom_role.id
      custom_role.delete
      account_user.custom_role_id = removed_id
      account_user.save!(validate: false)
      account_user.reload

      account_user.update!(availability: :busy)

      expect(account_user.reload.custom_role_id).to eq(removed_id)
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'preserves activity updates on an unchanged legacy foreign reference' do
      foreign_role = create(:custom_role)
      account_user.custom_role_id = foreign_role.id
      account_user.save!(validate: false)
      account_user.reload

      account_user.update!(active_at: Time.current)

      expect(account_user.reload.custom_role_id).to eq(foreign_role.id)
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'allows a legacy invalid link to be cleared' do
      account_user.custom_role_id = create(:custom_role).id
      account_user.save!(validate: false)
      account_user.reload

      account_user.update!(custom_role: nil)

      expect(account_user.reload.custom_role_id).to be_nil
    end
  end

  describe 'permission change notifications' do
    before do
      account_user.account.enable_features!(:custom_roles)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'notifies the affected user when the built-in role changes' do
      account_user.update!(role: :administrator)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.permissions_changed',
        kind_of(Time),
        account: account_user.account,
        user_id: account_user.user_id
      )
    end

    it 'notifies the affected user when the custom role changes' do
      custom_role = create(:custom_role, account: account_user.account, permissions: ['contact_manage'])

      account_user.update!(custom_role: custom_role)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.permissions_changed',
        kind_of(Time),
        account: account_user.account,
        user_id: account_user.user_id
      )
    end

    it 'does not notify while custom roles are disabled' do
      account_user.account.disable_features!(:custom_roles)

      account_user.update!(role: :administrator)

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(
        'account.permissions_changed',
        anything,
        anything
      )
    end
  end

  describe 'destroy call agent::destroy service' do
    it 'gets created with the right default settings' do
      create(:conversation, account: account_user.account, assignee: account_user.user, inbox: inbox)
      user = account_user.user

      expect(user.assigned_conversations.count).to eq(1)

      perform_enqueued_jobs do
        account_user.destroy!
      end

      expect(user.assigned_conversations.count).to eq(0)
    end
  end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:user) { create(:user) }
    let(:invalidator) { instance_double(Conversations::UnreadCounts::FilteredCountInvalidator, user_visibility_changed!: true) }

    before do
      allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).and_return(invalidator)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'invalidates filtered counts when the user is added to an account' do
      create(:account_user, account: account, user: user)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id)
    end

    it 'invalidates filtered counts when the user role changes' do
      account_user = create(:account_user, account: account, user: user)

      account_user.update!(role: :administrator)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
    end

    it 'invalidates filtered counts when the user is removed from an account' do
      account_user = create(:account_user, account: account, user: user)

      account_user.destroy!

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
    end
  end
end
