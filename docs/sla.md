# SLA policies

Orin Chat is rebuilding SLA support from public behaviour. The upstream MIT
codebase already contains the database tables (`sla_policies`, `applied_slas`,
`sla_events`), the dashboard settings/report screens, API clients and locale
strings; the backend was only shipped in the proprietary edition and is being
re-implemented.

## Implemented

- `SlaPolicy`: account-scoped definitions with name, description, first
  response, next response and resolution thresholds (seconds), and an
  `only_during_business_hours` flag. At least one threshold is required, and
  thresholds must be positive. Removing a policy clears the reference on
  linked conversations.
- Administrator-only CRUD at `/api/v1/accounts/:account_id/sla_policies`,
  scoped to the current account and available only to administrators (agents,
  bots and other tenants are denied). Payloads follow the dashboard contract:
  `name`, `description`, `first_response_time_threshold`,
  `next_response_time_threshold`, `resolution_time_threshold`,
  `only_during_business_hours`.
- The dashboard settings screen now explains that tracking is not available
  yet instead of showing an upgrade/paywall path. The `sla` account feature
  flag stays disabled, so the screen remains hidden from navigation.

## Not implemented yet

- Applying a policy to conversations and tracking first/next/resolution
  deadlines (`applied_slas`, `sla_events`).
- Business-hours calculation, breach events, notifications and reporting
  (`applied_slas` index/metrics/download endpoints).
- Automation integration for assigning a policy to conversations.
- Dashboard validation beyond the existing client-side rules, and the SLA
  reports screen.

Until those paths exist and are verified, the `sla` feature flag stays off
and no upgrade or payment path is shown.
