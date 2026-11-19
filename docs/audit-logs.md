# Audit Logs implementation and operations

Audit Logs is an open-source feature with no subscription requirement. Its API and dashboard are available to account administrators. Ordinary agents, administrators outside the account and agent bots cannot read an account's log.

## Recorded activity

- Successful user sign-ins and sign-outs, associated with each account the user belongs to. Super Admin impersonation sessions are excluded from the target user's own sign-in/sign-out trail; the existing impersonation logger records those sessions separately.
- Account settings updates, excluding internal attributes.
- Inbox, webhook, team, automation-rule and macro create/update/delete events. Webhook secrets are excluded.
- Account-agent creation/removal and selected membership/permission/availability
  changes, including custom role and agent capacity policy assignment; routine
  `active_at` updates are excluded.
- Inbox and team membership creation/removal.
- Direct conversation deletions, including the conversation's display ID, and message soft deletions. Message content and attachments are not copied into these explicit deletion events.

The declarations are in `config/initializers/audited.rb`. `AuditLog` extends the existing Audited storage rather than using proprietary upstream code.

## API contract

`GET /api/v1/accounts/:account_id/audit_logs`

Supported filters:

| Parameter | Meaning |
| --- | --- |
| `page` | Positive page number, default 1; 25 events per page |
| `sort` | `asc` or `desc`, default newest first; IDs break timestamp ties |
| `types[]` | Supported auditable model names exposed by the dashboard event filter |
| `since`, `until` | Inclusive Unix timestamp range; supply both in ascending order |
| `q` | Search text, at most 100 characters; matches actor name/email, recorded username, event type/action or remote address |

Invalid supported filter shapes/values return 422. The response contains
`audit_logs`, `current_page`, `per_page` and `total_entries`. It does not serialize full user, inbox or webhook records. Actor searches remain inside the account-scoped audit relation.

`GET /api/v1/accounts/:account_id/audit_logs/download` returns the same
filtered set as CSV (up to 10,000 rows), with timestamp, actor, action,
record type/id, changes JSON, IP address and location. The dashboard exposes
the download from the Audit Logs header.

## Retention

Retention is opt-in. Set the installation config
`AUDIT_LOG_RETENTION_DAYS` to a positive number to enable daily deletion of
older audit rows; blank or non-positive values keep logs indefinitely. The
`AuditLog::RetentionJob` runs daily at 03:30 UTC. There is no automatic
retention by default.

## Deletion and background-job consistency

Conversation destruction and its explicit audit write share a transaction. Message soft deletion, attachment deletion and its audit write likewise share a transaction. If the audit cannot be saved, the corresponding direct deletion rolls back.

`DeleteObjectJob` carries the supplied user/IP context through its association purges. Large account/inbox purges remain batched rather than holding one transaction across every child object. Deleting a whole inbox/account does not create one explicit conversation-deletion audit for every purged conversation. A multi-batch purge is not an all-or-nothing operation; retries and operational recovery still matter.

## New versus existing installations

`config/features.yml` enables `audit_logs` for fresh installation defaults. Super Admin lists the implemented feature as included, independently of legacy plan names.

Existing installations retain their saved `ACCOUNT_LEVEL_FEATURE_DEFAULTS` and account feature bits. An upgrade does not silently overwrite an explicit false setting. Enable the `audit_logs` account flag through Super Admin when required. To change defaults for future signups, run the existing interactive task:

```sh
bundle exec rake feature_defaults:toggle
```

That task does not backfill existing accounts. Core API authorization is always administrator-only, independent of dashboard visibility.

## Verification and limits

Focused backend tests cover tenant/role/bot access, actor search, filter handling, impersonation attribution, audit context, direct deletion rollback, membership deletion history, CSV export and opt-in retention. Frontend tests cover event payloads/action keys, filters, branding, policy and signup behavior. Run these checks on the assembled checkout rather than treating earlier source-worktree results as integration evidence. The installer guard has a separate local-stub test at `deployment/tests/upgrade_test.sh`; it never runs the production installer.

Local browser smoke checks exercised the real signup route on desktop/mobile, dashboard login, actor-email audit search/filter clearing and Super Admin included/planned presentation. A missing fallback favicon found during those checks was added from the existing Orin icon.

A local PostgreSQL probe used 50,000 synthetic audit rows across two tenants, with 45,000 rows assigned to the selected tenant. Executed page and actor-search plans used indexes; the unfiltered tenant count used a sequential scan. One warm run measured approximately 0.6 ms for a page, 0.9 ms for actor search and 6.2 ms for the count. Synthetic inserts were rolled back. These figures do not establish production capacity: high offsets, larger histories, many users, selective contains-text searches, cold caches and count costs still need workload-specific measurement.

Remaining operational work is workload-specific production validation (large
histories, high offsets, cold caches and contains-text searches) and
operator-side retention/export policy choices. No retention period is applied
unless configured, and exports are capped at 10,000 rows per request.
