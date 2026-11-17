# Required attributes on resolve

Administrators can require selected conversation custom attributes before an
agent resolves a conversation. The setting is the account's
`conversation_required_attributes` key list, managed from
`/settings/conversation-workflow` or the conversation attributes screen.

## Enforcement

- Manual single resolve (`POST .../conversations/:id/toggle_status`, including
  the no-params toggle) returns `422` with the missing attribute keys and
  leaves the conversation open.
- Bulk resolution validates every accessible selected conversation first. If
  any are missing values, the request returns `422` with per-conversation
  missing keys and no bulk job is enqueued.
- Macros that resolve (directly or through `change_status` set to resolved)
  skip the resolve action while attributes are missing.
- Automations, auto-resolve jobs and other internal transitions are not
  blocked, so background workflows keep their previous behavior.

An attribute is missing when its definition still exists and the conversation
value is `nil`/blank. Checkbox attributes treat `null` as unanswered and accept
`false` as a deliberate answer, matching the dashboard. Required keys whose
definition was deleted are ignored.

## Availability

`conversation_required_attributes` is enabled by default for new installations
and no longer marked premium. Existing installations keep their saved feature
defaults and account flags; enable it from Super Admin where required.

## Verification

Service and request specs cover blank/filled text, checkbox handling, deleted
definitions, feature-off behavior, single resolve, the no-params toggle,
non-resolution status changes, bulk validation, and macro resolution.
