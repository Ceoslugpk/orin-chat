json.payload @applied_slas do |applied_sla|
  json.applied_sla do
    json.partial! 'api/v1/models/applied_sla', formats: [:json], applied_sla: applied_sla
    json.sla_policy_id applied_sla.sla_policy_id
    json.conversation_id applied_sla.conversation_id
    json.created_at applied_sla.created_at
    json.updated_at applied_sla.updated_at
  end
  json.conversation do
    conversation = applied_sla.conversation
    json.id conversation.display_id
    json.uuid conversation.uuid
    json.account_id conversation.account_id
    json.labels conversation.cached_label_list
    json.contact do
      json.id conversation.contact&.id
      json.name conversation.contact&.name
    end
    if conversation.assignee
      json.assignee do
        json.partial! 'api/v1/models/agent', formats: [:json], resource: conversation.assignee
      end
    end
  end
  json.sla_events applied_sla.sla_events do |sla_event|
    json.partial! 'api/v1/models/sla_event', formats: [:json], sla_event: sla_event
  end
end
json.meta do
  json.count @applied_slas.total_count
  json.current_page @applied_slas.current_page
end
