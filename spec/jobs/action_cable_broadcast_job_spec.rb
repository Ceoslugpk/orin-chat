require 'rails_helper'

RSpec.describe ActionCableBroadcastJob do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:stale_data) { { id: conversation.display_id, account_id: account.id, status: 'open' } }

  before do
    conversation.update!(status: :resolved)
    allow(ActionCable.server).to receive(:broadcast)
  end

  it 'refreshes a conversation event with the full payload for agents and the widget payload for widget sessions' do
    described_class.perform_now(['agent-token'], Events::Types::CONVERSATION_STATUS_CHANGED, stale_data,
                                widget_members: ['widget-token'], widget_data: stale_data)

    expect(ActionCable.server).to have_received(:broadcast).with(
      'agent-token',
      { event: Events::Types::CONVERSATION_STATUS_CHANGED, data: conversation.reload.push_event_data.merge(account_id: account.id) }
    )
    expect(ActionCable.server).to have_received(:broadcast).with(
      'widget-token',
      { event: Events::Types::CONVERSATION_STATUS_CHANGED, data: conversation.reload.widget_push_event_data.merge(account_id: account.id) }
    )
  end

  it 'sends the prebuilt payloads for events that are not refreshed' do
    widget_data = { id: 1, account_id: account.id }
    described_class.perform_now(['agent-token'], Events::Types::MESSAGE_CREATED, { id: 1, content: 'hi', account_id: account.id },
                                widget_members: ['widget-token'], widget_data: widget_data)

    expect(ActionCable.server).to have_received(:broadcast).with(
      'agent-token', { event: Events::Types::MESSAGE_CREATED, data: { id: 1, content: 'hi', account_id: account.id } }
    )
    expect(ActionCable.server).to have_received(:broadcast).with(
      'widget-token', { event: Events::Types::MESSAGE_CREATED, data: widget_data }
    )
  end

  it 'sends widget sessions their payload when there are no agent members' do
    described_class.perform_now([], Events::Types::CONVERSATION_STATUS_CHANGED, stale_data,
                                widget_members: ['widget-token'], widget_data: stale_data)

    expect(ActionCable.server).to have_received(:broadcast).once.with(
      'widget-token',
      { event: Events::Types::CONVERSATION_STATUS_CHANGED, data: conversation.reload.widget_push_event_data.merge(account_id: account.id) }
    )
  end

  describe 'custom role delivery authorization' do
    let(:inbox) { conversation.inbox }
    let(:allowed_user) { create(:user, account: account, role: :agent) }
    let(:denied_user) { create(:user, account: account, role: :agent) }
    let(:removed_user) { create(:user, account: account, role: :agent) }

    before do
      account.enable_features!(:custom_roles)
      [allowed_user, denied_user, removed_user].each { |user| create(:inbox_member, user: user, inbox: inbox) }
      allowed_user.account_users.find_by!(account: account).update!(
        custom_role: create(:custom_role, account: account, permissions: ['conversation_manage'])
      )
      denied_user.account_users.find_by!(account: account).update!(
        custom_role: create(:custom_role, account: account, permissions: ['contact_manage'])
      )
    end

    it 'filters restricted recipients that lost conversation access' do
      described_class.perform_now([allowed_user.pubsub_token, denied_user.pubsub_token],
                                  Events::Types::CONVERSATION_STATUS_CHANGED, stale_data)

      expect(ActionCable.server).to have_received(:broadcast).with(allowed_user.pubsub_token, anything)
      expect(ActionCable.server).not_to have_received(:broadcast).with(denied_user.pubsub_token, anything)
    end

    it 'filters recipients removed from the inbox' do
      InboxMember.find_by!(user: removed_user, inbox: inbox).destroy!

      described_class.perform_now([removed_user.pubsub_token], Events::Types::CONVERSATION_STATUS_CHANGED, stale_data)

      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it 'filters message broadcasts for lost access' do
      message = create(:message, conversation: conversation, account: account)

      described_class.perform_now([denied_user.pubsub_token], Events::Types::MESSAGE_CREATED,
                                  message.push_event_data.merge(account_id: account.id))

      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it 'filters mention broadcasts for lost access' do
      described_class.perform_now([denied_user.pubsub_token], Events::Types::CONVERSATION_MENTIONED,
                                  conversation.push_event_data.merge(account_id: account.id))

      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it 'filters notification broadcasts for lost access' do
      notification = create(:notification, user: denied_user, account: account, primary_actor: conversation)

      described_class.perform_now([denied_user.pubsub_token], Events::Types::NOTIFICATION_CREATED,
                                  { notification: notification.push_event_data, account_id: account.id })

      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it 'filters contact events by contact permission' do
      contact = create(:contact, account: account)

      described_class.perform_now([allowed_user.pubsub_token, denied_user.pubsub_token], Events::Types::CONTACT_CREATED,
                                  contact.push_event_data.merge(account_id: account.id))

      expect(ActionCable.server).to have_received(:broadcast).with(denied_user.pubsub_token, anything)
      expect(ActionCable.server).not_to have_received(:broadcast).with(allowed_user.pubsub_token, anything)
    end

    it 'keeps client and widget tokens while filtering user tokens' do
      described_class.perform_now(['widget-token', denied_user.pubsub_token], Events::Types::MESSAGE_CREATED,
                                  { conversation_id: conversation.display_id, account_id: account.id, content: 'hi' })

      expect(ActionCable.server).to have_received(:broadcast).with('widget-token', anything)
      expect(ActionCable.server).not_to have_received(:broadcast).with(denied_user.pubsub_token, anything)
    end

    it 'keeps prior delivery when custom roles are disabled' do
      account.disable_features!(:custom_roles)

      described_class.perform_now([denied_user.pubsub_token], Events::Types::CONVERSATION_STATUS_CHANGED, stale_data)

      expect(ActionCable.server).to have_received(:broadcast).with(denied_user.pubsub_token, anything)
    end

    it 'drops a queued conversation broadcast after inbox removal' do
      clear_enqueued_jobs
      described_class.perform_later([removed_user.pubsub_token], Events::Types::CONVERSATION_STATUS_CHANGED, stale_data)
      InboxMember.find_by!(user: removed_user, inbox: inbox).destroy!

      perform_enqueued_jobs(only: described_class)

      expect(ActionCable.server).not_to have_received(:broadcast).with(
        removed_user.pubsub_token, hash_including(event: Events::Types::CONVERSATION_STATUS_CHANGED)
      )
    end

    it 'delivers a queued conversation broadcast after access is granted' do
      clear_enqueued_jobs
      described_class.perform_later([denied_user.pubsub_token], Events::Types::CONVERSATION_STATUS_CHANGED, stale_data)
      denied_user.account_users.find_by!(account: account).update!(
        custom_role: create(:custom_role, account: account, permissions: ['conversation_manage'])
      )

      perform_enqueued_jobs(only: described_class)

      expect(ActionCable.server).to have_received(:broadcast).with(
        denied_user.pubsub_token, hash_including(event: Events::Types::CONVERSATION_STATUS_CHANGED)
      )
    end

    it 'reauthorizes a queued contact broadcast after the role permissions change' do
      contact = create(:contact, account: account)
      clear_enqueued_jobs
      described_class.perform_later([allowed_user.pubsub_token], Events::Types::CONTACT_CREATED,
                                    contact.push_event_data.merge(account_id: account.id))
      allowed_user.account_users.find_by!(account: account).update!(
        custom_role: create(:custom_role, account: account, permissions: ['contact_manage'])
      )

      perform_enqueued_jobs(only: described_class)

      expect(ActionCable.server).to have_received(:broadcast).with(
        allowed_user.pubsub_token, hash_including(event: Events::Types::CONTACT_CREATED)
      )
    end
  end
end
