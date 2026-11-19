# Orin Chat

**The free, open-source, self-hosted customer support platform.**

Orin Chat brings together what teams usually pay several vendors for: an
omnichannel inbox, a full ticketing system, a help center, AI assistance, and
WhatsApp/Shopify commerce tools. Run it on your own server, keep your data,
and pay nothing per agent.

> **Status: early development.** Orin Chat is a fork of
> [Chatwoot](https://github.com/chatwoot/chatwoot) and currently ships
> Chatwoot's open-source feature set. Items marked _planned_ below are on the
> roadmap and not yet available.

## Features

### Omnichannel inbox — available
- Website live chat widget, email, WhatsApp (Cloud API), Facebook Messenger,
  Instagram, Telegram, LINE, SMS, TikTok and a generic API channel
- Shared team inbox with assignment, private notes, @mentions, labels and
  saved views
- Canned responses, macros, event-based automation rules
- Contacts, companies, custom attributes and segments
- CSAT surveys, reports, webhooks, agent bots, dashboard apps

### Ticketing (Zendesk-style) — _planned_
- Ticket statuses (New, Open, Pending, On-hold, Solved, Closed), ticket types,
  custom fields and forms
- Triggers (event-based) and automations (time-based)
- SLA policies with business-hours schedules
- Custom roles, SSO (SAML), audit logs, skills-based routing

### Help center — available, being extended
- Multi-portal knowledge base with categories and articles

### Commerce and WhatsApp marketing (DelightChat-style) — _planned_
- Shopify order context and actions inside the inbox
- WhatsApp order notifications, COD verification, abandoned-cart recovery,
  back-in-stock alerts
- Broadcasts with segments, opt-out management and revenue attribution
- Instagram and Facebook comment replies

### AI — _planned_
- AI agent that answers from your help center and past conversations
- Reply drafting, summaries, tone and translation
- Bring your own model provider

## Self-hosting

Orin Chat is designed to run on a single server (4 cores / 4 GB RAM handles
roughly 10,000 conversations a day). Orin-specific install instructions are
coming; there is not yet a supported self-hosting guide for Orin Chat.

**Privacy:** Orin Chat does not send telemetry or usage data to anyone.

## Development

Requirements: Ruby (see `.ruby-version`), Node 24, pnpm 10, PostgreSQL with
pgvector, Redis.

```bash
bundle install && pnpm install
bundle exec rails db:chatwoot_prepare
pnpm dev
```

Contributor guidelines live in [AGENTS.md](AGENTS.md).

## License

Orin Chat is licensed under the [GNU AGPL-3.0](LICENSE). If you run a modified
version as a network service, you must make your source code available to its
users.

Orin Chat is a fork of Chatwoot. Code from Chatwoot is © Chatwoot Inc. under
the MIT license, preserved in [LICENSE-CHATWOOT](LICENSE-CHATWOOT). Orin Chat
contains none of Chatwoot's proprietary `enterprise/` code. See
[NOTICE](NOTICE).

Orin Chat is an independent project, not affiliated with Chatwoot Inc.
