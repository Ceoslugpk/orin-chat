require 'rails_helper'

RSpec.describe RoomChannel do
  let!(:contact_inbox) { create(:contact_inbox) }
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  before do
    stub_connection
  end

  it 'subscribes to a stream when pubsub_token is provided' do
    subscribe(pubsub_token: contact_inbox.pubsub_token)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(contact_inbox.pubsub_token)
  end

  it 'subscribes to a stream when pubsub_token is provided for user' do
    subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(user.pubsub_token)
    expect(subscription).to have_stream_for("account_#{account.id}")
  end

  it 'sends the agent their work preferences with presence' do
    user.account_users.find_by(account: account).update!(accepts_calls: false)

    expect { subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id) }
      .to have_broadcasted_to(user.pubsub_token).with(
        hash_including(data: hash_including(work_preferences: { 'accepts_conversations' => true, 'accepts_calls' => false }))
      )
  end

  it 'does not send work preferences to a contact' do
    expect { subscribe(pubsub_token: contact_inbox.pubsub_token) }
      .to have_broadcasted_to(contact_inbox.pubsub_token).with(hash_including(data: hash_excluding(:work_preferences)))
  end

  describe 'restricted custom role presence' do
    before do
      account.enable_features!(:custom_roles)
      allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
        { 'unrelated-user' => 'online', user.id.to_s => 'online' }
      )
      allow(OnlineStatusTracker).to receive(:get_available_contacts).and_return({ 'contact' => 'online' })
    end

    def link_custom_role(*permissions)
      user.account_users.find_by!(account: account).update!(
        custom_role: create(:custom_role, account: account, permissions: permissions)
      )
    end

    it 'scopes online users to shared inboxes and omits contacts without contact_manage' do
      link_custom_role('conversation_manage')

      expect { subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id) }
        .to have_broadcasted_to(user.pubsub_token).with(
          hash_including(data: {
                           account_id: account.id,
                           users: { user.id.to_s => 'online' },
                           work_preferences: { 'accepts_conversations' => true, 'accepts_calls' => true }
                         })
        )
    end

    it 'includes contacts when contact_manage is granted' do
      link_custom_role('contact_manage')

      expect { subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id) }
        .to have_broadcasted_to(user.pubsub_token).with(
          hash_including(data: {
                           account_id: account.id,
                           users: { user.id.to_s => 'online' },
                           contacts: { 'contact' => 'online' },
                           work_preferences: { 'accepts_conversations' => true, 'accepts_calls' => true }
                         })
        )
    end
  end
end
