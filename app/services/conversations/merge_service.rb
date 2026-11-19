class Conversations::MergeService
  class InvalidMerge < StandardError; end

  def initialize(source:, target:, user:)
    @source = source
    @target = target
    @user = user
  end

  def perform
    validate!

    Conversation.transaction do
      move_messages
      move_reporting_events
      copy_participants
      merge_attributes
      merge_labels
      merge_assignment
      update_timestamps
      remove_links
      create_activity_message
      source.destroy!
    end

    target.reload
  end

  private

  attr_reader :source, :target, :user

  def validate!
    raise InvalidMerge, I18n.t('errors.conversation.merge_same_conversation') if source.id == target.id
    raise InvalidMerge, I18n.t('errors.conversation.merge_account_mismatch') unless source.account_id == target.account_id
    raise InvalidMerge, I18n.t('errors.conversation.merge_contact_mismatch') unless source.contact_id == target.contact_id
  end

  def move_messages
    source.messages.update_all(conversation_id: target.id) # rubocop:disable Rails/SkipsModelValidations
  end

  def move_reporting_events
    source.reporting_events.update_all(conversation_id: target.id) # rubocop:disable Rails/SkipsModelValidations
  end

  def copy_participants
    source.conversation_participants.find_each do |participant|
      target.conversation_participants.find_or_create_by!(user_id: participant.user_id) do |new_participant|
        new_participant.account_id = target.account_id
      end
    end
  end

  def merge_attributes
    target.custom_attributes = source.custom_attributes.merge(target.custom_attributes)
    target.additional_attributes = source.additional_attributes.merge(target.additional_attributes)
  end

  def merge_labels
    target.label_list = (source.label_list + target.label_list).uniq
  end

  def merge_assignment
    target.assignee ||= source.assignee
    target.team ||= source.team
  end

  def update_timestamps
    target.first_reply_created_at = [source.first_reply_created_at, target.first_reply_created_at].compact.min
    target.last_activity_at = [source.last_activity_at, target.last_activity_at].compact.max
    target.save!
  end

  def remove_links
    ConversationLink.where('conversation_id = :id OR linked_conversation_id = :id', id: source.id).delete_all
  end

  def create_activity_message
    target.messages.create!(
      account_id: target.account_id,
      inbox_id: target.inbox_id,
      message_type: :activity,
      content: I18n.t('conversations.activity.merged', source_id: source.display_id, user_name: user.name)
    )
  end
end
