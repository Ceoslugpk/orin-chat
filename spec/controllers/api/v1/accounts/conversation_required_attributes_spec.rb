require 'rails_helper'

RSpec.describe 'Required conversation attributes on resolve', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, status: :open) }

  before do
    create(:inbox_member, user: agent, inbox: conversation.inbox)
    account.enable_features!('conversation_required_attributes')
    account.update!(settings: account.settings.merge('conversation_required_attributes' => ['order_id']))
    create(:custom_attribute_definition, account: account, attribute_key: 'order_id',
                                         attribute_model: :conversation_attribute,
                                         attribute_display_type: :text)
  end

  it 'blocks manual resolution until the attribute is filled' do
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
         headers: agent.create_new_auth_token,
         params: { status: 'resolved' },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to include(
      'error' => 'Fill the required conversation attributes before resolving.',
      'missing_attributes' => ['order_id']
    )
    expect(conversation.reload).to be_open
  end

  it 'blocks the no-params toggle path as well' do
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(conversation.reload).to be_open
  end

  it 'resolves once the attribute is filled' do
    conversation.update!(custom_attributes: { 'order_id' => 'ORD-42' })

    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
         headers: agent.create_new_auth_token,
         params: { status: 'resolved' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to be_resolved
  end

  it 'does not block non-resolution status changes' do
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
         headers: agent.create_new_auth_token,
         params: { status: 'pending' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to be_pending
  end

  it 'does not block resolution when the feature is disabled' do
    account.disable_features!('conversation_required_attributes')

    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
         headers: agent.create_new_auth_token,
         params: { status: 'resolved' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to be_resolved
  end

  it 'blocks bulk resolution when any conversation is missing attributes' do
    expect do
      post "/api/v1/accounts/#{account.id}/bulk_actions",
           headers: agent.create_new_auth_token,
           params: { type: 'Conversation', fields: { status: 'resolved' }, ids: [conversation.display_id] },
           as: :json
    end.not_to have_enqueued_job(BulkActionsJob)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['conversations'].first).to include(
      'id' => conversation.display_id,
      'missing_attributes' => ['order_id']
    )
  end

  it 'allows bulk resolution once attributes are filled' do
    conversation.update!(custom_attributes: { 'order_id' => 'ORD-42' })

    expect do
      post "/api/v1/accounts/#{account.id}/bulk_actions",
           headers: agent.create_new_auth_token,
           params: { type: 'Conversation', fields: { status: 'resolved' }, ids: [conversation.display_id] },
           as: :json
    end.to have_enqueued_job(BulkActionsJob)

    expect(response).to have_http_status(:success)
  end
end
