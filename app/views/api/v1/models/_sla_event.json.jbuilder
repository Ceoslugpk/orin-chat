json.extract! sla_event, :id, :event_type, :meta
json.created_at sla_event.created_at.to_i
