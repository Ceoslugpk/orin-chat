# Orin Chat Roadmap

Orin Chat aims to give every team, for free, what Zendesk, DelightChat and
Chatwoot's paid editions sell: an omnichannel inbox, rigorous ticketing, AI,
and commerce tools, all self-hosted.

Status legend: ✅ done · 🚧 in progress · ⬜ planned

## How we build features

1. **Spec from public sources only.** Behaviour comes from public product
   documentation and from Chatwoot's MIT-licensed dashboard code (whose API
   contracts we implement). Chatwoot's proprietary `enterprise/` code is never
   read or copied (see `AGENTS.md`, Licensing and Clean-Room Rules).
2. **Reuse what exists.** Many removed features still have their MIT
   dashboard screens, API routes and database tables; we implement the missing
   backend against those contracts before building new UI.
3. **Every feature is free.** No plan gating or upsells. Complete local
   features may default on; external integrations remain opt-in and require
   valid configuration. Keep unfinished backends off and label them planned.
   Preserve explicit installation/account settings during upgrades.
4. **Definition of done:** models/services/controllers with policies, request
   and model specs, RuboCop/ESLint clean, affected suites green, dashboard
   checked in a real browser, documented here.

## Phase 0: Foundation ✅

- ✅ Clean import of Chatwoot's MIT core, no proprietary code in history
- ✅ AGPL-3.0 licence, attribution (`NOTICE`, `LICENSE-CHATWOOT`)
- ✅ No calls to Chatwoot servers; push relay opt-in
- ✅ Rebrand (logos, defaults, all locales via installation name)
- ✅ Containerised dev toolbox (`bin/toolbox`)

## Phase 0.5: Free and unbranded 🚧

- 🚧 Remove remaining paywalls: Super Admin planned/included presentation
  and dashboard feature policy are integrated; remaining account-feature,
  cloud/enterprise, billing and limit paths still need inventory and validation
- 🚧 Remove remaining user-facing Chatwoot branding and links (help docs,
  community links, status page, "Powered by"); preserve legal attribution
  and upstream-compatible internal identifiers
- ⬜ "Powered by" branding off by default and controllable per account
- ⬜ Custom branding page in Super Admin (name, logos, URLs) for white-labelling
- ⬜ Make supported integrations and complete features available without
  subscription gates (Linear, Notion, CRM, Stripe, Shopify custom apps,
  custom reply email/domain, branded email templates, delayed automations,
  WhatsApp embedded signup, …). External services stay opt-in and require
  valid configuration; unfinished backends remain disabled.

## Phase 1: Enterprise parity (rebuild removed features) 🚧

| # | Feature | Status | Notes |
|---|---|---|---|
| 1.1 | Audit logs | 🚧 | Backend/API and dashboard integrated; assembled tests/lint/build and browser smoke checks passed. Query plans inspected on 50,000 synthetic rows. Remaining change-rendering/lifecycle coverage and operational limits tracked in [Audit Logs](audit-logs.md). |
| 1.2 | Custom roles & permissions | ✅ | One custom role per agent; permissions: all/unassigned/participating conversations, contacts, reports, knowledge base; enforced in policies, REST scopes, realtime delivery and the dashboard. Enabled by default for new installations; existing accounts opt in from Super Admin. See [Custom Roles](custom-roles.md). |
| 1.3 | SLA policies | 🚧 | Account-scoped policy definitions with administrator-only CRUD, applied-SLA records with business-hours-aware due timestamps, the `add_sla` automation action, and hit/missed completion with first-response/resolution events and reopen handling are implemented behind the disabled feature flag. Next-response misses, breach jobs/notifications, conversation serialization and reports remain. See [SLA](sla.md). |
| 1.4 | Agent capacity & balanced assignment | ⬜ | Per-inbox conversation limits, balanced vs round-robin, exclusion rules |
| 1.5 | Required attributes on resolve | ⬜ | Block manual resolve until chosen custom attributes are filled |
| 1.6 | Merge & link conversations | ⬜ | Permanent merge with history; linked/related conversations |
| 1.7 | SAML SSO | ⬜ | Per-account SAML 2.0, role mapping, JIT provisioning; SCIM later |
| 1.8 | Advanced search | ⬜ | Full-text search over messages/contacts/conversations with filters, PostgreSQL-native (no extra search server required) |

## Phase 2: AI (provider-agnostic) ⬜

Works with any OpenAI-compatible endpoint, Anthropic, or a local model
(Ollama), configured by the administrator.

- Knowledge base for AI: help-center articles, URLs (crawl), PDFs, FAQs;
  FAQ suggestions from resolved conversations; coverage gaps
- AI agent per inbox: guardrails, tone guidelines, scenarios/playbooks,
  handoff rules, schedule and audience, playground, citations, reports
- Custom HTTP tools for the AI agent (auth, verification before sensitive
  actions)
- Copilot for agents: reply drafts, summaries, tone/grammar, look-ups
- Auto-triage: labels, priority, intent, language, sentiment; natural
  language automation conditions
- Two-way auto-translation, voice-note/call transcripts, contact memories

## Phase 3: Commerce and WhatsApp marketing (DelightChat parity) ⬜

- Shopify order sidebar actions: view, edit, refund, duplicate, cancel,
  tracking, product and checkout links; multi-store
- WhatsApp COD verification and COD→prepaid conversion
- Abandoned cart/checkout recovery with expiring coupons
- Order notifications, back-in-stock alerts, review requests
- WhatsApp campaigns at scale: segments, scheduling, throttling to Meta tiers,
  per-recipient variables, opt-outs, delivery/read analytics
- Segments and journeys from store data; revenue attribution
- WhatsApp catalog sync; product messages
- Visual chatbot flow builder
- Facebook/Instagram comment inbox with public reply / move to DM
- Self-service order status in the widget
- WooCommerce support

## Phase 4: Zendesk depth ⬜

- Custom ticket statuses (grouped under new/open/pending/on-hold/solved)
- Ticket forms with conditional and per-status required fields
- Time-based automations (hourly rules over ticket age)
- Side conversations and parent/child conversations
- Light agents (internal notes only)
- Skills-based and omnichannel routing
- Voice calls (Twilio, WhatsApp Calling) with recordings/transcripts
- CSAT extras (review notes, WhatsApp templates outside 24h window)
- Custom report and dashboard builder with scheduled delivery

## Phase 5: Later ⬜

QA scorecards and AI quality review, multibrand, help-center community and
reusable content blocks, time tracking and checklists, workforce management,
sandbox, custom objects, proactive messaging, CRM connectors (HubSpot, Zoho,
Attio), Zapier/n8n, Jira, Calendly/Cal.com.

## Self-hosting track (runs alongside all phases) ⬜

- One-command Docker Compose install with guided first-run setup
- Upgrade and backup/restore tooling: the installer has an isolated,
  regression-tested fail-closed upgrade guard; legacy migration, supported
  OS/toolchain validation and end-to-end backup/restore remain planned.
- Kubernetes Helm chart
- Orin Chat release builds and an opt-in release check
