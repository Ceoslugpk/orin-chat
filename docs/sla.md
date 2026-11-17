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
- Dashboard settings, reports, sidebar entries and report routes are gated by
  the account `sla` flag. Accounts without the flag keep the previous
  unavailable state and no upgrade/paywall path.
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
- Breach checks are scheduled for each applied due time and re-check the
  conversation state when they run: first response only when no in-time
  reply exists, next response only while the customer is still waiting, and
  resolution only while unresolved. Miss events are recorded once per
  deadline (NRT once per waiting cycle) and notify the assignee, falling
  back to inbox members.
- Next-response deadlines are recomputed from `waiting_since` after the
  first reply and cleared when the waiting period ends. Miss notifications
  use the existing in-app/email/push notification settings and mailer
  templates, including the policy name.
- Realtime conversation payloads include the current applied SLA and its
  events while the account flag is enabled, so message-driven updates keep
  the SLA card current. The SLA settings and reports routes, sidebar entries
  and report route guard all follow the account `sla` flag.
- Lifecycle coverage exercises automation assignment, conversation payloads,
  breach jobs and notifications, completion, reopen and reports in one flow.
  Business-hours deadlines are covered across closed weekends and non-UTC
  inbox timezones.
- Browser smoke checks against a disposable environment validated the policy
  settings screen, an active conversation countdown, a breached conversation
  label, and the reports page (metrics and conversation rows). The policy form
  also rejects submissions without at least one threshold.
- The `sla` account feature is enabled by default for new installations and
  no longer marked premium. Existing accounts stay opted out until a Super
  Admin enables the flag for them.

## Not implemented yet

- Holiday-specific business hours. The `working_hours` gem supports them,
  but inboxes do not store holiday calendars yet.

The `sla` feature is active for new installations. Existing accounts can
enable it from Super Admin; the dashboard hides SLA settings, reports and
conversation labels until the account flag is on.
