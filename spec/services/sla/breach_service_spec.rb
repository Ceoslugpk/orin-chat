require 'rails_helper'

RSpec.describe Sla::BreachService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let(:policy) do
    create(
      :sla_policy,
      account: account,
      first_response_time_threshold: 3600,
      next_response_time_threshold: 900,
      resolution_time_threshold: 7200
    )
  end
  let(:applied_sla) do
    create(:applied_sla, account: account, conversation: conversation, sla_policy: policy, sla_status: 'active')
  end

  before do
    account.enable_features!('sla')
    create(:inbox_member, inbox: inbox, user: agent)
  end

  def breach(event_type)
    described_class.new(applied_sla, event_type).perform
  end

  describe 'first response breach' do
    before { applied_sla.update!(sla_frt_due_at: 1.minute.ago) }

    it 'records the event and notifies the assignee' do
      setting = agent.notification_settings.find_by(account_id: account.id)
      setting.selected_email_flags = [:email_sla_missed_first_response]
      setting.save!

      expect { breach(:frt) }.to change { agent.notifications.count }.by(1)

      event = applied_sla.sla_events.last
      expect(event.event_type).to eq('frt')
      expect(event.meta['due_at']).to eq(applied_sla.sla_frt_due_at.iso8601)
      expect(agent.notifications.last.notification_type).to eq('sla_missed_first_response')
    end

    it 'does not duplicate the event' do
      breach(:frt)

      expect { breach(:frt) }.not_to(change { applied_sla.sla_events.count })
    end

    it 'does not record a miss when the first response was in time' do
      conversation.update!(first_reply_created_at: 2.minutes.ago)

      expect { breach(:frt) }.not_to(change { applied_sla.sla_events.count })
    end

    it 'does nothing while the feature is disabled' do
      account.disable_features!('sla')

      expect { breach(:frt) }.not_to(change { applied_sla.sla_events.count })
    end
  end

  describe 'resolution breach' do
    before { applied_sla.update!(sla_rt_due_at: 1.minute.ago) }

    it 'records the event while the conversation is unresolved' do
      expect { breach(:rt) }.to change { applied_sla.sla_events.count }.by(1)

      expect(applied_sla.sla_events.last.event_type).to eq('rt')
    end

    it 'does not record a miss for a resolved conversation' do
      conversation.update!(status: :resolved)

      expect { breach(:rt) }.not_to(change { applied_sla.sla_events.count })
    end
  end

  describe 'next response breach' do
    before do
      conversation.update!(first_reply_created_at: 1.hour.ago)
      conversation.update!(waiting_since: 20.minutes.ago)
      applied_sla.update!(sla_nrt_due_at: 10.minutes.ago)
    end

    it 'records one event per waiting cycle' do
      expect { breach(:nrt) }.to change { applied_sla.sla_events.count }.by(1)
      expect { breach(:nrt) }.not_to(change { applied_sla.sla_events.count })

      applied_sla.update!(sla_nrt_due_at: 5.minutes.ago)
      expect { breach(:nrt) }.to change { applied_sla.sla_events.count }.by(1)
    end

    it 'does not record a miss once the conversation is no longer waiting' do
      conversation.update!(waiting_since: nil)

      expect { breach(:nrt) }.not_to(change { applied_sla.sla_events.count })
    end
  end
end
