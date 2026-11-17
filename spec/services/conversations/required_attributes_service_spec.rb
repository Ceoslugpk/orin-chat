require 'rails_helper'

RSpec.describe Conversations::RequiredAttributesService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  def configure_required_attributes(key, display_type: :text)
    account.enable_features!('conversation_required_attributes')
    account.update!(settings: account.settings.merge('conversation_required_attributes' => [key]))
    create(:custom_attribute_definition, account: account, attribute_key: key,
                                         attribute_model: :conversation_attribute,
                                         attribute_display_type: display_type)
  end

  it 'returns required keys only while the feature is enabled' do
    configure_required_attributes('order_id')

    expect(described_class.new(conversation).required_keys).to eq(['order_id'])

    account.disable_features!('conversation_required_attributes')
    expect(described_class.new(conversation).required_keys).to be_empty
  end

  it 'reports missing and blank text attributes' do
    configure_required_attributes('order_id')

    expect(described_class.new(conversation).missing_attributes).to eq(['order_id'])

    conversation.update!(custom_attributes: { 'order_id' => '   ' })
    expect(described_class.new(conversation).missing_attributes).to eq(['order_id'])
  end

  it 'accepts filled text and falsy non-checkbox values' do
    configure_required_attributes('order_id')
    conversation.update!(custom_attributes: { 'order_id' => 'ORD-1' })

    expect(described_class.new(conversation).missing_attributes).to be_empty
  end

  it 'treats checkbox null as missing and false as answered' do
    configure_required_attributes('approved', display_type: :checkbox)

    expect(described_class.new(conversation).missing_attributes).to eq(['approved'])

    conversation.update!(custom_attributes: { 'approved' => false })
    expect(described_class.new(conversation).missing_attributes).to be_empty
  end

  it 'ignores required keys whose definition was deleted' do
    account.enable_features!('conversation_required_attributes')
    account.update!(settings: account.settings.merge('conversation_required_attributes' => ['deleted_key']))

    expect(described_class.new(conversation).missing_attributes).to be_empty
  end
end
