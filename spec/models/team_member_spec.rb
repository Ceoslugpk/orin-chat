require 'rails_helper'

RSpec.describe TeamMember do
  include ActiveJob::TestHelper

  describe 'associations' do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'permission change notifications' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:user) { create(:user) }

    before do
      account.enable_features!(:custom_roles)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'notifies the user when team access is added' do
      create(:team_member, team: team, user: user)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.permissions_changed',
        kind_of(Time),
        account: account,
        user_id: user.id
      )
    end

    it 'notifies the user when team access is removed' do
      team_member = create(:team_member, team: team, user: user)

      team_member.destroy!

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.permissions_changed',
        kind_of(Time),
        account: account,
        user_id: user.id
      ).twice
    end
  end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:team) { create(:team, account: account) }
    let(:user) { create(:user) }
    let(:store) { Conversations::UnreadCounts::FilteredCountStore }

    before do
      account.enable_features!(:unread_count_for_filters)
    end

    it 'invalidates the user built-in filter version when team access is added' do
      expect do
        create(:team_member, team: team, user: user)
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates the user built-in filter version when team access is removed' do
      team_member = create(:team_member, team: team, user: user)

      expect do
        team_member.destroy!
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates the user built-in filter version when the parent team is removed' do
      create(:team_member, team: team, user: user)

      expect do
        perform_enqueued_jobs { team.destroy! }
      end.to change { store.built_in_filter_version(account_id: account.id, user_id: user.id) }.by(1)
    end

    it 'invalidates saved filter snapshots when the parent team is removed' do
      create(:conversation, account: account, team: team)

      expect do
        perform_enqueued_jobs { team.destroy! }
      end.to change { store.conversation_version(account.id) }.by(1)
    end
  end
end
