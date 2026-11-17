json.extract! applied_sla, :id, :sla_status
json.sla_name applied_sla.sla_policy.name
json.sla_completed_at applied_sla.completed_at&.to_i
json.sla_frt_due_at applied_sla.sla_frt_due_at&.to_i
json.sla_nrt_due_at applied_sla.sla_nrt_due_at&.to_i
json.sla_rt_due_at applied_sla.sla_rt_due_at&.to_i
