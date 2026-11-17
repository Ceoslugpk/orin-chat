# Orin Chat — engineering handover

Snapshot: 2026-11-16. This file is a manual status/runbook, not an automatic backup. Read `AGENTS.md` first; its project rules take precedence over optional coding skills.

## 1. Find the actual current code

Current branch: **`worktree-orin-chat-custom-roles`**, based on `9fbf54161` plus substantial **uncommitted changes and untracked source files**. No recent milestone has been committed, merged, pushed or released.

On the current machine, the main repository contains the active copy at `.claude/worktrees/orin-chat-custom-roles`. The main, branding, Super Admin and integration worktrees are older preserved snapshots. Do not reset, clean, delete or reimport them over the active copy. The main directory's `HANDOVER.md` is a local pointer to this file.

If this active folder was supplied as a standalone source snapshot, treat it as the project root instead; do not append the worktree path again. A worktree's `.git` file alone does not include repository metadata. Confirm what was transferred before using Git commands.

Start with:

```sh
git status --short --branch
git worktree list
```

When transferring to another machine/agent, include the actual active source and untracked files. A branch/remote at `9fbf54161` is not the current implementation. Exclude `.env`, credentials, browser session data and private database dumps from ordinary code handoffs.

## 2. Product and non-negotiable constraints

Orin Chat is a free, self-hostable AGPL-3.0 helpdesk built from Chatwoot's MIT core, with broader support, AI and commerce functionality planned.

- Never read/copy proprietary upstream `enterprise/` implementations. Rebuild from public behavior and MIT interfaces only.
- Preserve `LICENSE-CHATWOOT`, `NOTICE`, upstream-compatible internal identifiers, environment variable names and API paths.
- No paid tiers or upgrade gates. Unfinished implementations must remain unavailable rather than appearing unlocked.
- External integrations are opt-in/configuration-dependent; no telemetry by default.
- Do not enable Custom Roles or remove its assignment guard until REST **and realtime/queued delivery** authorization are complete together.
- No commit/push without the user's request. No production installer execution or development-database reset for testing.

Ponytail's core skill was installed for the current user, in default full mode. It is optional workflow guidance, not an application dependency. No Ponytail hooks, statusline, ledger, webhook or auxiliary skills were installed. Prefer the smallest complete change, never reduced security/validation or compressed unreadable code.

## 3. Implemented versus unfinished

| Area | Implemented / verified | Still unfinished |
| --- | --- | --- |
| Foundation | Fork/licensing/attribution, toolbox, initial branding and telemetry changes | Production delivery/upgrade validation is separate |
| Branding/readiness | Combined branding/link/changelog/testimonial cleanup, dashboard feature policy, honest Super Admin included/planned states, fallback favicon | Remaining account/cloud/billing gates, widget/email controls, full white-labelling and integration inventory |
| Audit Logs | Models/API/dashboard, actor search, impersonation-safe session attribution, transactional direct-deletion audits, purge context, agent-removal and role-definition events | Remaining change descriptions, wider lifecycle/concurrency/filter coverage, retention/export and production-scale measurement |
| Custom Role definitions | Admin-only tenant-scoped CRUD, permission validation, referenced-role deletion protection, account cleanup and audit history; API documented in the generated OpenAPI spec. | Optional: broader lifecycle/filter coverage and production-scale measurement of definition queries. |
| Role linkage / atomic updates | Model ownership/existence/agent-only validation; legacy-safe unrelated updates; explicit clears through dashboard/platform; atomic identity/member writes; editor preserves unchanged metadata. Positive assignment is enabled through both APIs and the agent builder; invalid/foreign/administrator links return 422 without changing access. Feature is enabled by default for new installations. | Optional: broader queue/lifecycle coverage for assignment changes. |
| Effective permission source | `AccountUser#permissions` resolves administrator, ordinary agent or the linked role's permissions; missing/foreign definitions or a legacy `administrator` permission fail closed. Unread counter modes, definition-change invalidation and agent `custom_role_id` serialization are in place. Dashboard pickers hide custom roles when the account feature is off and preserve inactive metadata on unrelated edits. | Optional: simultaneous multi-process concurrency measurement. |
| Conversation scopes | Role modes are shared by `Conversations::PermissionFilterService` (lists, advanced filters, search, contact/company history, attachments, bulk actions, counts, filtered unread) and `ConversationPolicy` (creation plus direct reads/mutations, messages, labels, assignments, participants, drafts, uploads). Scopes retain assigned-inbox boundaries, union unassigned/participating, and deny conversation access without a conversation permission, including creation. Administrators, ordinary agents, bots and widget/public paths are unchanged. Real-browser restricted/broadened/revoked flows passed. | Optional multi-process concurrency measurement. |
| Contact, report and knowledge-base gates | `contact_manage` gates the contact API and bypasses (nested notes/labels/contact-inboxes, company contacts, merge, bulk actions, search, import/export, contact-inbox lookup); `report_manage` gates every v2 report controller and drilldown; `knowledge_base_manage` gates portal/article/category management while index/read and public published content stay open. Custom roles without the permission fail closed; ordinary agents, admins, bots and public paths keep prior behavior. Real-browser denied-before/granted-after contact and report checks passed. | Optional broader nested-path browser coverage. |
| Delivery-time authorization | `Conversations::AccessService` centralizes per-user access, and `ConversationPolicy` now delegates to it. `ActionCableBroadcastJob` resolves user tokens and re-checks current access for conversation, message, typing, mention and notification events; widget/client tokens and non-conversation account events pass through. Push and email services re-check access before sending. Queued jobs therefore observe role, custom-role and inbox/team changes. Feature disabled keeps prior delivery behavior. | Queue-delay covered; optional multi-process concurrency measurement. |
| Shared streams, presence, credentials and client purge | With custom roles enabled, contact create/update/merge/delete events target individual user tokens and the delivery job drops recipients without contact access; disabled installations keep the account stream. Presence scopes online users to shared assigned inboxes plus admins/self and includes contacts only with `contact_manage`; membership is re-read on each broadcast. Role, custom-role, inbox and team membership changes emit `account.permissions_changed` to the affected user and the dashboard reloads, discarding all cached data. Credential review found no dashboard ContactInbox pubsub-token exposure (only `source_id`/inbox); user tokens are self-only and widget/public/platform endpoints are intentional. Added contact payload and permission-event regression assertions; real-browser role-change/inbox-removal revocation passed. | Complete; optional broader browser coverage. |

Role-definition API: `/api/v1/accounts/:account_id/custom_roles`. Supported keys: `conversation_manage`, `conversation_unassigned_manage`, `conversation_participating_manage`, `contact_manage`, `report_manage`, `knowledge_base_manage`.

`custom_roles` is enabled by default for new installations; existing accounts keep their stored feature bit and can be enabled in Super Admin. Assignment is active. Ordinary agent/administrator effective permissions remain unchanged unless a role is assigned. Names are labels; IDs identify roles. Duplicate labels are preserved rather than adding an unsafe uniqueness migration, and the picker/list disambiguate repeated labels with the definition ID.

## 4. Code map and design documents

- `docs/ROADMAP.md`: full product roadmap and current phase statuses.
- `docs/custom-roles.md`: staged API contract and activation/security gates.
- `docs/audit-logs.md`: audit behavior, existing-account enablement and limits.
- `app/models/custom_role.rb`, `app/policies/custom_role_policy.rb`, `app/controllers/api/v1/accounts/custom_roles_controller.rb`: definition API.
- `app/models/account_user.rb`: membership, role reference and effective permission source; do not confuse configured metadata with active permissions.
- `app/controllers/api/v1/accounts/agents_controller.rb`, `app/controllers/platform/api/v1/account_users_controller.rb`: membership write boundaries.
- `app/services/conversations/permission_filter_service.rb`, `app/policies/conversation_policy.rb`: key future REST scope boundaries; enumerate their callers before editing.
- `app/channels/room_channel.rb`, `app/listeners/action_cable_listener.rb`, `app/jobs/action_cable_broadcast_job.rb`: critical realtime boundaries.
- `app/builders/notification_builder.rb`, mention/notification/push services: queued/direct delivery also needs current authorization.

The realtime inventory found shared account contact/presence streams and enqueue-time recipients without restricted-role reauthorization at delivery. Direct mentions and notifications/push need coverage too. A possible ContactInbox/pubsub-token exposure requires targeted verification; it is not an established fix. Do not trust a hidden sidebar or cache invalidation alone.

Local-only detailed checkpoints, if supplied with the main repository, live under `.claude/`: `PROJECT_MEMORY.md`, `PLAN_STATUS.md`, `AGENT_HANDOFFS.md`, `CUSTOM_ROLES_MEMORY.md`. They are ignored by Git and are not required to understand this handover.

## 5. Build/test environment

Application: Rails 8, Ruby 3.4.4, Vue 3, Node 24, pnpm 10. PostgreSQL 16 with pgvector and Redis are required. `bin/toolbox` runs the toolchain in Podman/Docker; see `README.md` and `docker/dockerfiles/toolbox.Dockerfile`.

On the current machine, use the main repository's `bin/toolbox`, which mounts main at `/app`, then change inside the container to `/app/.claude/worktrees/orin-chat-custom-roles`. For a normal standalone checkout, its own `bin/toolbox` mounts that checkout at `/app` instead. Do not accidentally test the older main code.

Existing local services: `orin-postgres`, `orin-redis`, `orin-mailhog`. Use a distinct disposable PostgreSQL database and Redis DB for tests. Definition-foundation checks used `orin_chat_custom_roles_test` and Redis DB 13. The current membership-layer run uses `orin_chat_role_links_test` and Redis DB 14. Both now contain synthetic browser fixtures/defaults. Do not reuse it as an unseeded baseline without deliberately preparing this disposable database. Never reset development/production data.

Portable commands once services/environment/dependencies are configured in the correct checkout:

Provision a new disposable test database and its schema separately first. No database-reset command is included here.

```sh
export RAILS_ENV=test
export POSTGRES_DATABASE="${ROLE_TEST_DATABASE:?Set ROLE_TEST_DATABASE to a confirmed-disposable test database}"
export REDIS_URL="${ROLE_TEST_REDIS_URL:?Set ROLE_TEST_REDIS_URL to a separate Redis database URL}"
bin/vite build
VITE_RUBY_AUTO_BUILD=false bundle exec rspec spec/models/custom_role_spec.rb spec/policies/custom_role_policy_spec.rb spec/controllers/api/v1/accounts/custom_roles_controller_spec.rb spec/models/account_user_spec.rb spec/controllers/api/v1/accounts/agents_controller_spec.rb spec/controllers/platform/api/v1/account_users_controller_spec.rb
bundle exec rubocop app/models/account_user.rb app/controllers/concerns/custom_role_assignment_guard.rb app/controllers/api/v1/accounts/agents_controller.rb app/controllers/platform/api/v1/account_users_controller.rb
pnpm exec eslint app/javascript/dashboard/routes/dashboard/settings/agents/EditAgent.vue app/javascript/dashboard/routes/dashboard/settings/agents/specs/EditAgent.spec.js
```

Build assets **before** HTML request specs. Running them alongside an unfinished build caused five missing-manifest/font errors; the subsequent full rerun passed. Configure all three test-only `ACTIVE_RECORD_ENCRYPTION_*` values to exercise MFA rather than skipping those tests. Do not save production keys in docs/tests.

The local worktree reuses main `node_modules` via an ignored symlink. Its ignored `tmp/vitest.worktree.config.mts` allows the real dependency directory in Vite's filesystem allowlist. Standalone transfers should install their own dependencies rather than retain a broken symlink. Vitest can then use the ordinary repository config.

Prior browser smoke used a test-only Rails server on 3106, isolated Chromium on 9336, synthetic fixtures, and no external requests. Both were stopped. Temporary scripts/artifacts are optional and may disappear; do not depend on `/tmp` surviving a handoff.

## 6. Verification status and known observations

Current membership-layer checks: **336 RSpec examples, 0 failures; 80 frontend tests; changed Ruby/JS lint and fresh frontend build passed.** Six API clearing/atomicity/platform-parity failures and two editor-intent failures were reproduced before their fixes. Prior definition-foundation results (309 Ruby / 75 frontend and live definition CRUD/audits) are historical, not substitutes for the current rerun.

Canonical permission-source checks: **92 RSpec examples, 0 failures** across account-user, custom-role, unread-counter and agents-API specs, plus **73 examples, 0 failures** across custom-role API, platform-membership, audit-log and policy specs. RuboCop is clean on the seven changed Ruby/spec files. The `custom_roles` flag remains false; positive assignment is still rejected and no authorization path is activated.

Conversation-scope checks: **111 focused examples** (filter service, conversation policy, finder, bulk job, filter service alignment), **357 consumer examples** (conversation controllers, messages/assignments/labels/participants/drafts/uploads, contact history/attachments, search, unread counts) and **122 policy/conversations-controller examples** after adding creation gating, all with 0 failures. RuboCop is clean on the changed Ruby/spec files. Administrators, ordinary agents, bots and widget/public paths keep their prior behavior while the flag is off.

Contact/report/knowledge-base checks: **240 policy and request examples** plus **151 consumer examples** passed with 0 failures; RuboCop is clean on all 25 changed files. Decisions: `contact_manage` grants the full contact surface (including merge, import/export, bulk and company views), `report_manage` grants all v2 reports including drilldown, and `knowledge_base_manage` grants help-center management while authenticated index/read and public published content stay open. Roles without the permission fail closed; ordinary agents, admins, bots and public paths are unchanged.

Delivery-time checks: **640 notification, message, listener, realtime, conversations-controller and unread-count examples**, including the gate-4 job/push/email cases, passed with 0 failures on a fresh disposable test database. RuboCop is clean on the nine changed files. `Conversations::AccessService` is now the shared per-user access source; the broadcast job filters user tokens for conversation, message, typing, mention and notification events, and push/email re-check before sending. Widget/client tokens and non-conversation account events pass through; the flag being off preserves prior delivery. The shared test database has a pre-existing `INSTALLATION_EVENTS_WEBHOOK_URL` config collision unrelated to this work; the suite is green on a fresh DB.

Shared-stream checks: **713 channel, listener, notification, job, contact, policy, unread and message examples** passed with 0 failures on a fresh disposable database; RuboCop is clean on the ten changed files. Contact events now target per-user tokens when the flag is enabled and are filtered by contact access at delivery; presence scopes users to shared inboxes plus admins/self and gates contacts on `contact_manage`. Credential review found no dashboard ContactInbox token leak and added a regression assertion. Shared DB config collision noted above still applies.

Permission-purge checks: **93 model/listener examples** passed, including role, custom-role, inbox and team membership events; the dashboard `actionCable` suite passed **20/20** and ESLint is clean. A **554-example** clean-DB regression had one pre-existing `Team` translation-load failure (`en.errors.validations.presence` missing at class load), unrelated to this change; every other example passed. Role, custom-role, inbox and team changes now emit a targeted `account.permissions_changed` event and the client reloads to discard cached data.

Browser/lifecycle pass: **5/5 checks** passed in isolated headless Chromium against a disposable test DB and rebuilt assets, with no runtime exceptions, failed responses or third-party requests. Restricted role: unassigned/own conversation tabs show only allowed contacts; another-agent and out-of-inbox conversations, contacts and reports are denied. After assigning a broader role directly in the test DB: the API and direct conversation route broaden, the "All 3" view appears, and Contacts/Reports become readable. After removing the inbox membership: the conversation list and direct route revoke. Artifacts: `tmp/role-lifecycle-smoke/results.json` and four screenshots; harness `tmp/role-lifecycle-smoke.mjs`, fixtures `tmp/prepare_role_lifecycle_fixtures.rb`. The temporary server, Chromium and database were stopped/dropped.

The first browser run observed one custom-attribute API 500; an immediate direct request returned 200 and the full rerun was clean. Cause was not established. If reproduced, capture response/trace details rather than claiming it fixed. Existing warnings include large frontend chunks, stale Browserslist data, deprecated Rack status aliases and duplicate custom-cop constants from nested checkout lint.

Current step: **Custom Roles completed and activated (2026-11-17)**. Positive assignment works through the dashboard, agent builder and platform API with same-account/agent-only validation; the feature is enabled for fresh installation defaults and available to existing accounts through Super Admin. Role-picker duplicates are disambiguated, the definition API is in the generated OpenAPI spec, queue-delay delivery reauthorization is covered, and a real-browser check assigned a role and verified its enforcement. Remaining work is optional hardening (multi-process concurrency and broader browser coverage).

## 7. Exact next work after the current step

1. The canonical effective-permission source, fail-closed resolution, counter integration, agent read serialization and positive assignment are implemented and active. Keep the assignment validation (same-account, existing definition, agent-only) when extending membership write paths.
2. Conversation scopes are implemented across lists, advanced filters, search, contact/company history, attachments, bulk actions, counts, filtered unread and direct conversation actions; the browser pass covers restricted/broadened/revoked flows and assigned-role enforcement. Optional next: concurrency measurement.
3. Contact/report/knowledge-base gates are implemented, including the merge, company-contact, nested, bulk, search and export bypasses; denied-before/granted-after browser checks passed. Optional next: broader nested-path browser coverage.
4. Delivery-time authorization, shared contact/presence stream filtering, credential review and targeted client purge are implemented; queue-delay specs cover revocation and later granting. Optional next: multi-process concurrency measurement.
5. Custom Roles is complete for this milestone. Continue with Phase 1.3 (SLA) or the Phase 0.5/Audit Logs/self-hosting backlog.

After Phase 1.2: SLA, capacity/balanced assignment, required resolve attributes, merge/link conversations, SAML and advanced search remain planned. AI, commerce/WhatsApp, deeper ticketing and later connectors follow. Keep Phase 0.5, remaining Audit Logs work and production self-hosting/backup/restore in the parallel backlog; none is complete just because definition CRUD works.
