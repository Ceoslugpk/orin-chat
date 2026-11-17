require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:another_conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when user is an agent' do
      it 'returns all conversations with no further filtering' do
        inbox_ids = agent.inboxes.where(account_id: account.id).pluck(:id)

        # The base implementation returns all conversations
        # expecting the caller to filter by assigned inboxes
        result = described_class.new(
          account.conversations.where(inbox_id: inbox_ids),
          agent,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when plan_hint_selective_filter is enabled' do
      let!(:other_inbox) { create(:inbox, account: account) }
      let!(:inaccessible_conversation) { create(:conversation, account: account, inbox: other_inbox) }

      it 'returns the same conversations as the default scoping for an agent' do
        default_result = described_class.new(account.conversations, agent, account).perform
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_a).to match_array(default_result.to_a)
        expect(hinted_result).not_to include(inaccessible_conversation)
      end

      it 'keeps the planner hint in the generated query' do
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_sql).to include('conversations.inbox_id + 0')
      end

      it 'does not change administrator scoping' do
        result = described_class.new(account.conversations, admin, account, plan_hint_selective_filter: true).perform

        expect(result.to_sql).not_to include('inbox_id + 0')
        expect(result).to include(inaccessible_conversation)
      end
    end

    context 'with a restricted custom role' do
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let(:other_inbox) { create(:inbox, account: account) }
      let!(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox) }
      let!(:assigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
      let!(:other_agent_conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }
      let!(:participant_conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }
      let!(:inaccessible_conversation) { create(:conversation, account: account, inbox: other_inbox) }

      before do
        create(:conversation_participant, account: account, conversation: participant_conversation, user: agent)
        account.enable_features!(:custom_roles)
        agent.account_users.find_by!(account: account).update!(custom_role: create(:custom_role, account: account, permissions: permissions))
      end

      def filtered_conversations
        described_class.new(account.conversations, agent, account).perform
      end

      context 'with conversation_manage' do
        let(:permissions) { ['conversation_manage'] }

        it 'returns every conversation in assigned inboxes' do
          result = filtered_conversations

          expect(result).to include(unassigned_conversation, assigned_conversation, other_agent_conversation, participant_conversation)
          expect(result).not_to include(inaccessible_conversation)
        end
      end

      context 'with conversation_unassigned_manage' do
        let(:permissions) { ['conversation_unassigned_manage'] }

        it 'returns unassigned and own conversations only' do
          result = filtered_conversations

          expect(result).to include(conversation, another_conversation, unassigned_conversation, assigned_conversation)
          expect(result).not_to include(other_agent_conversation, participant_conversation, inaccessible_conversation)
        end
      end

      context 'with conversation_participating_manage' do
        let(:permissions) { ['conversation_participating_manage'] }

        it 'returns participating and own conversations only' do
          result = filtered_conversations

          expect(result).to include(assigned_conversation, participant_conversation)
          expect(result).not_to include(conversation, another_conversation, unassigned_conversation, other_agent_conversation)
          expect(result).not_to include(inaccessible_conversation)
        end
      end

      context 'with both unassigned and participating scopes' do
        let(:permissions) { %w[conversation_unassigned_manage conversation_participating_manage] }

        it 'combines the scopes' do
          result = filtered_conversations

          expect(result).to include(conversation, another_conversation, unassigned_conversation, assigned_conversation,
                                    participant_conversation)
          expect(result).not_to include(other_agent_conversation, inaccessible_conversation)
        end
      end

      context 'without a conversation permission' do
        let(:permissions) { ['contact_manage'] }

        it 'returns no conversations' do
          expect(filtered_conversations).to be_empty
        end
      end

      context 'when custom roles are disabled' do
        let(:permissions) { ['conversation_participating_manage'] }

        before { account.disable_features!(:custom_roles) }

        it 'keeps ordinary agent inbox scoping' do
          result = filtered_conversations

          expect(result).to include(unassigned_conversation, assigned_conversation, other_agent_conversation, participant_conversation)
          expect(result).not_to include(inaccessible_conversation)
        end
      end
    end
  end
end
