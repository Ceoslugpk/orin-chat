# Assignment policies and agent capacity

Assignment V2 and capacity-based assignment are open-source features with no
subscription requirement. Both are administrator-only in the dashboard and
platform APIs.

## Assignment policies

`AssignmentPolicy` lives at `/api/v1/accounts/:account_id/assignment_policies`
and is linked to inboxes through `InboxAssignmentPolicy` (one policy per
inbox). A policy controls:

- `assignment_order`: `round_robin` or `balanced`.
- `conversation_priority`: `earliest_created` or `longest_waiting`.
- Fair distribution (`fair_distribution_limit` per
  `fair_distribution_window` seconds).
- `exclude_older_than_hours` for stale unassigned conversations.
- `enabled`.

The dashboard routes are `/settings/assignment-policy` (settings cards),
`/settings/assignment-policy/assignment` (list/create/edit) and
`/settings/assignment-policy/capacity` (agent capacity).

## Agent capacity

`AgentCapacityPolicy` and `InboxCapacityLimit` are managed at
`/api/v1/accounts/:account_id/agent_capacity_policies`:

- Policy CRUD: `index`, `create`, `show`, `update`, `destroy`
  (`name`, `description`, `exclusion_rules`).
- Agent assignment: nested `users` (`index`, `create`, `destroy`); each agent
  belongs to at most one capacity policy.
- Inbox limits: nested `inbox_limits` (`create`, `update`, `destroy`) with a
  positive `conversation_limit` per inbox.

Capacity counting uses open conversations assigned to the agent in that
inbox. Conversations matching the policy's exclusion rules do not count:
labels in `exclusion_rules.excluded_labels` and conversations whose
`last_activity_at` is older than `exclude_older_than_hours`. An inbox without
a limit is unlimited. Per-agent capacity overrides are not stored; limits are
defined per inbox on the policy.

Capacity filters are applied to Assignment V1 and V2, including team-based
assignment. A `balanced` policy picks the agent with the most remaining
capacity, using round robin only to break ties among unlimited or equally
loaded agents.

## Availability and defaults

- `assignment_v2` is enabled by default for new installations.
- `advanced_assignment` is enabled by default and no longer marked premium.
- Existing installations keep their saved feature defaults and account flags.
  Enable `advanced_assignment` from Super Admin where required; the capacity
  settings card and routes stay hidden until the account flag is on.

## Verification

Model, request and service specs cover policy CRUD, nested agents and inbox
limits, tenant/role rejection, capacity counting, exclusion rules, the
capacity selector and assignment filters. A local browser smoke check covered
the assignment settings cards, capacity list/editor with assigned agents and
inbox limits, and balanced assignment without a premium gate.
