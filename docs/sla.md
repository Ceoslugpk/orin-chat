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
- `AppliedSla` and `SlaEvent` records with status and event enums, account
  consistency validation and per-policy/conversation uniqueness. Due
  timestamps for first response, next response and resolution are stored on
  the applied record.
- Applying a policy to a conversation creates one active applied SLA with
  business-hours-aware due times when the policy requires them. The
  `add_sla` automation action assigns an account-owned policy; both the
  action and the conversation callback do nothing while the `sla` account
  flag is disabled.
- Resolving a conversation completes the applied SLA as `hit` or `missed`,
  recording first-response and resolution miss events (without duplicates)
  and the completion time. Reopening a completed conversation restores
  `active` or `active_with_misses` and clears the completion time.
- Conversation API payloads expose the current `applied_sla` (with policy
  name, status, completion and due times) and its `sla_events` when the
  account flag is enabled. Conversation lists preload applied SLAs and their
  events while tracking is enabled, so the status card does not add
  per-conversation queries.
- Reports backend at `/api/v1/accounts/:account_id/applied_slas`
  (`index`, `metrics`, `download`), available to administrators and custom
  roles with report access while the account flag is enabled. Supports date
  range, policy, agent, inbox, team and label filters. Metrics report total
  applied SLAs, conversations with misses (`missed`/`active_with_misses`)
  and the hit rate; download returns a CSV matching the existing locale
  headers.

## Not implemented yet

- Next-response miss detection. FRT and RT misses are evaluated at
  resolution; NRT requires per-waiting-cycle tracking and breach jobs.
- Breach detection while a conversation is still open (jobs), miss
  notifications and the dashboard SLA status card's live updates (the card
  renders from API data today; realtime payloads do not include SLA fields
  yet).
- Business-hours calculation for policies applied while the inbox is closed
  is implemented for due timestamps; holiday and audit-grade timezone
  coverage still needs verification.
- Automation UI exposure for self-hosted accounts (the dashboard action is
  still gated on a cloud check) and end-to-end policy assignment through the
  automation builder.
- Dashboard validation of policy names and thresholds beyond the existing
  client-side rules.

Until those paths exist and are verified, the `sla` feature flag stays off
and no upgrade or payment path is shown.
