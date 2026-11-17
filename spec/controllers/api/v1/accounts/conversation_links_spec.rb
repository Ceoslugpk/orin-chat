require 'rails_helper'

RSpec.describe 'Conversation links and merges API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:linked_conversation) { create(:conversation, account: account, contact: contact) }
  let(:headers) { administrator.create_new_auth_token }

  describe 'links' do
    it 'creates, lists and removes a link' do
      expect do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/links",
             headers: headers,
             params: { linked_conversation_id: linked_conversation.display_id },
             as: :json
      end.to change(ConversationLink, :count).by(1)

      expect(response).to have_http_status(:created)
      link_id = response.parsed_body['id']
      expect(response.parsed_body.dig('conversation', 'id')).to eq(linked_conversation.display_id)

      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/links",
          headers: headers,
          as: :json
      expect(response.parsed_body.length).to eq(1)
      expect(response.parsed_body.first['conversation']['id']).to eq(linked_conversation.display_id)

      delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/links/#{link_id}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(ConversationLink.count).to eq(0)
    end

    it 'rejects a conversation from another account' do
      foreign_conversation = create(:conversation)
      foreign_conversation.update_column(:display_id, 99_999) # rubocop:disable Rails/SkipsModelValidations

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/links",
           headers: headers,
           params: { linked_conversation_id: foreign_conversation.display_id },
           as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'requires access to the source conversation' do
      agent = create(:user, account: account, role: :agent)

      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/links",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'merge' do
    it 'merges the source conversation into the target' do
      create(:message, account: account, inbox: conversation.inbox, conversation: conversation, content: 'history')
      create(:message, account: account, inbox: linked_conversation.inbox, conversation: linked_conversation, content: 'target')

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/merge",
           headers: headers,
           params: { target_conversation_id: linked_conversation.display_id },
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.dig('merged_into', 'id')).to eq(linked_conversation.display_id)
      expect(Conversation.exists?(conversation.id)).to be(false)
      expect(linked_conversation.messages.pluck(:content)).to include('history', 'target')
    end

    it 'rejects merging different contacts' do
      other_conversation = create(:conversation, account: account, contact: create(:contact, account: account))

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/merge",
           headers: headers,
           params: { target_conversation_id: other_conversation.display_id },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Conversation.exists?(conversation.id)).to be(true)
    end
  end
end
