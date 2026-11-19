require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }

  let(:conversation) { create(:conversation, account: account) }

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows destroy' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when user is an agent' do
      it 'denies destroy' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end

  permissions :index? do
    context 'when user is authenticated' do
      it 'allows index' do
        expect(subject).to permit(agent_context, conversation)
      end
    end
  end

  permissions :create? do
    it 'allows ordinary agents' do
      expect(subject).to permit(agent_context, Conversation)
    end
  end

  permissions :show? do
    context 'when user is an administrator' do
      it 'allows access' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when agent has inbox access' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent has team access' do
      let(:team) { create(:team, account: account) }
      let(:conversation) { create(:conversation, :with_team, account: account, team: team) }

      before { create(:team_member, team: team, user: agent) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent lacks inbox and team access' do
      let(:conversation) { create(:conversation, account: account) }

      it 'denies access' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end

  describe 'custom role scopes' do
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:custom_role) { create(:custom_role, account: account, permissions: permissions) }
    let(:custom_role_agent_context) do
      { user: agent, account: account, account_user: agent.account_users.find_by!(account: account) }
    end

    before do
      account.enable_features!(:custom_roles)
      create(:inbox_member, user: agent, inbox: inbox)
      agent.account_users.find_by!(account: account).update!(custom_role: custom_role)
    end

    def show_allowed?(record)
      described_class.new(custom_role_agent_context, record).show?
    end

    context 'with conversation_manage' do
      let(:permissions) { ['conversation_manage'] }

      it 'allows conversations in assigned inboxes' do
        expect(show_allowed?(conversation)).to be(true)
      end

      it 'denies team-only conversations outside assigned inboxes' do
        team = create(:team, account: account)
        create(:team_member, team: team, user: agent)
        team_conversation = create(:conversation, :with_team, account: account, team: team)

        expect(show_allowed?(team_conversation)).to be(false)
      end
    end

    context 'with conversation_unassigned_manage' do
      let(:permissions) { ['conversation_unassigned_manage'] }

      it 'allows unassigned conversations' do
        expect(show_allowed?(conversation)).to be(true)
      end

      it 'allows own assigned conversations' do
        conversation.update!(assignee: agent)

        expect(show_allowed?(conversation)).to be(true)
      end

      it 'denies another agent conversation' do
        conversation.update!(assignee: create(:user, account: account))

        expect(show_allowed?(conversation)).to be(false)
      end
    end

    context 'with conversation_participating_manage' do
      let(:permissions) { ['conversation_participating_manage'] }

      it 'allows participating conversations' do
        conversation.update!(assignee: create(:user, account: account))
        create(:conversation_participant, account: account, conversation: conversation, user: agent)

        expect(show_allowed?(conversation)).to be(true)
      end

      it 'denies unassigned conversations without participation' do
        expect(show_allowed?(conversation)).to be(false)
      end
    end

    context 'without a conversation permission' do
      let(:permissions) { ['contact_manage'] }

      it 'denies conversation access even when assigned' do
        conversation.update!(assignee: agent)

        expect(show_allowed?(conversation)).to be(false)
      end

      it 'denies conversation creation' do
        expect(described_class.new(custom_role_agent_context, Conversation).create?).to be(false)
      end
    end

    context 'with a conversation permission' do
      let(:permissions) { ['conversation_unassigned_manage'] }

      it 'allows conversation creation' do
        expect(described_class.new(custom_role_agent_context, Conversation).create?).to be(true)
      end
    end

    context 'when custom roles are disabled' do
      let(:permissions) { ['contact_manage'] }

      before { account.disable_features!(:custom_roles) }

      it 'keeps ordinary agent inbox access' do
        expect(show_allowed?(conversation)).to be(true)
      end
    end
  end
end
