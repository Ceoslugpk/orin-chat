require 'rails_helper'

RSpec.describe ConversationLink, type: :model do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:first_conversation) { create(:conversation, account: account, contact: contact) }
  let(:second_conversation) { create(:conversation, account: account, contact: contact) }

  it 'stores one canonical link per pair' do
    link = described_class.link!(account: account, conversation: first_conversation,
                                 linked_conversation: second_conversation)
    same_link = described_class.link!(account: account, conversation: second_conversation,
                                      linked_conversation: first_conversation)

    expect(same_link).to eq(link)
    expect(described_class.count).to eq(1)
  end

  it 'exposes linked conversations from both sides' do
    described_class.link!(account: account, conversation: first_conversation,
                          linked_conversation: second_conversation)

    expect(first_conversation.linked_conversations.pluck(:id)).to eq([second_conversation.id])
    expect(second_conversation.linked_conversations.pluck(:id)).to eq([first_conversation.id])
  end

  it 'rejects linking a conversation to itself' do
    link = described_class.new(account: account, conversation: first_conversation,
                               linked_conversation: first_conversation)

    expect(link).not_to be_valid
  end

  it 'rejects links across accounts' do
    foreign_conversation = create(:conversation)
    link = described_class.new(account: account, conversation: first_conversation,
                               linked_conversation: foreign_conversation)

    expect(link).not_to be_valid
  end
end
