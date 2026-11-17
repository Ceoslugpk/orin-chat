FactoryBot.define do
  factory :conversation_link do
    account
    association :conversation, factory: :conversation
    association :linked_conversation, factory: :conversation

    after(:build) do |link|
      link.account ||= link.conversation&.account
      link.conversation, link.linked_conversation = [link.conversation, link.linked_conversation].sort_by(&:id)
    end
  end
end
