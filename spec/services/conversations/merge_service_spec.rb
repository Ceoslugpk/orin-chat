require 'rails_helper'

RSpec.describe Conversations::MergeService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:source) { create(:conversation, account: account, contact: contact, status: :open) }
  let(:target) { create(:conversation, account: account, contact: contact, status: :open) }

  it 'moves messages into the target' do
    source_message = create(:message, account: account, inbox: source.inbox, conversation: source, content: 'source')
    target_message = create(:message, account: account, inbox: target.inbox, conversation: target, content: 'target')

    merged = described_class.new(source: source, target: target, user: user).perform

    expect(merged.id).to eq(target.id)
    expect(Conversation.exists?(source.id)).to be(false)
    expect(target.messages.pluck(:content)).to include('source', 'target')
    expect(target.messages.find_by(id: source_message.id).conversation_id).to eq(target.id)
    expect(target.messages.find_by(id: target_message.id).conversation_id).to eq(target.id)
  end

  it 'merges metadata into the target' do
    source.update!(custom_attributes: { 'order_id' => 'SRC' }, label_list: ['billing'])
    target.update!(custom_attributes: { 'order_id' => 'TGT', 'priority_note' => 'keep' })

    described_class.new(source: source, target: target, user: user).perform

    expect(target.custom_attributes).to include('order_id' => 'TGT', 'priority_note' => 'keep')
    expect(target.label_list).to include('billing')
    expect(target.messages.where(message_type: :activity).last.content).to include('#')
  end

  it 'moves participants without duplicating them' do
    participant = create(:conversation_participant, conversation: source, account: account, user: user)
    create(:conversation_participant, conversation: target, account: account, user: user)

    described_class.new(source: source, target: target, user: user).perform

    expect(target.conversation_participants.where(user_id: participant.user_id).count).to eq(1)
  end

  it 'rejects merging conversations with different contacts' do
    other_contact_conversation = create(:conversation, account: account, contact: create(:contact, account: account))

    expect do
      described_class.new(source: source, target: other_contact_conversation, user: user).perform
    end.to raise_error(Conversations::MergeService::InvalidMerge, /same contact/)
    expect(Conversation.exists?(source.id)).to be(true)
  end

  it 'removes links attached to the merged conversation' do
    other = create(:conversation, account: account, contact: contact)
    ConversationLink.link!(account: account, conversation: source, linked_conversation: other)

    described_class.new(source: source, target: target, user: user).perform

    expect(ConversationLink.count).to eq(0)
    expect(other.reload.linked_conversations).to be_empty
  end
end
