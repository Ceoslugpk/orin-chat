# Merge and link conversations

## Linking

Conversations can be linked symmetrically for context. A single
`ConversationLink` row stores the canonical pair (lower conversation ID
first), so linking either direction returns the same record.

- `GET /api/v1/accounts/:account_id/conversations/:conversation_id/links`
- `POST .../links` with `linked_conversation_id` (display ID)
- `DELETE .../links/:id`

Links are account-scoped, require access to both conversations, reject
self-links and cross-account links, and are removed automatically when either
conversation is deleted or merged. The dashboard exposes them from
Conversation → More actions → Related conversations.

## Merging

`POST .../conversations/:conversation_id/merge` with
`target_conversation_id` merges the source conversation into the target. Only
conversations with the same contact in the same account can be merged.

The merge transaction:

- Moves messages and reporting events to the target, preserving timestamps
  and attachments.
- Copies conversation participants without duplicating existing ones.
- Merges labels (union) and custom/additional attributes (target wins on
  conflicts).
- Fills a missing target assignee/team from the source.
- Keeps the earliest first-reply time and latest activity time.
- Adds an activity message recording the merged source conversation.
- Removes links involving the source and then deletes the source conversation.

The target keeps its inbox, status and SLA policy. The dashboard offers the
same flow from Related conversations, requires an explicit permanent-merge
confirmation, and navigates to the target after merging.

## Verification

Model and request specs cover canonical/deduplicated links, both-direction
lookups, self/cross-account rejection, link create/list/delete, merge
validation, message and metadata movement, participants, link cleanup and
API responses. The dashboard bundle builds with the new modal and menu entry.
