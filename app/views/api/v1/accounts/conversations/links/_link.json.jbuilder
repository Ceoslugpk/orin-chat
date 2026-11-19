json.id link.id
json.created_at link.created_at.to_i
other_conversation = link.other_conversation(@conversation.id)
json.conversation do
  json.id other_conversation.display_id
  json.uuid other_conversation.uuid
  json.status other_conversation.status
  json.created_at other_conversation.created_at.to_i
  json.last_activity_at other_conversation.last_activity_at.to_i
  json.inbox do
    json.id other_conversation.inbox_id
    json.name other_conversation.inbox&.name
  end
  json.contact do
    json.id other_conversation.contact_id
    json.name other_conversation.contact&.name
  end
end
