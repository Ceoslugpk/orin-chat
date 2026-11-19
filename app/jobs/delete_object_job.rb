class DeleteObjectJob < ApplicationJob
  queue_as :low

  BATCH_SIZE = 5_000

  def perform(object, user = nil, ip = nil)
    AuditLog.with_context(user: user, ip: ip) do
      # Keep large purges batched, while attributing their audits to the actor.
      purge_heavy_associations(object)
      object.class.transaction do
        object.destroy!
        process_post_deletion_tasks(object, user, ip)
      end
    end
  end

  def process_post_deletion_tasks(object, user, _ip)
    record_conversation_deletion(object, user) if object.is_a?(Conversation)
  end

  private

  # Conversations are audited here rather than through a destroy callback, so
  # deleting an inbox or account does not write one audit per conversation.
  def record_conversation_deletion(conversation, user)
    AuditLog.record!(auditable: conversation, account: conversation.account, action: 'destroy', user: user,
                     changes: { display_id: conversation.display_id })
  end

  def heavy_associations
    {
      Account => %i[conversations contacts inboxes reporting_events],
      Inbox => %i[conversations contact_inboxes reporting_events]
    }.freeze
  end

  def purge_heavy_associations(object)
    klass = heavy_associations.keys.find { |k| object.is_a?(k) }
    return unless klass

    heavy_associations[klass].each do |assoc|
      next unless object.respond_to?(assoc)

      batch_destroy(object.public_send(assoc))
    end
  end

  def batch_destroy(relation)
    relation.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch.each(&:destroy!)
    end
  end
end

DeleteObjectJob.prepend_mod_with('DeleteObjectJob')
