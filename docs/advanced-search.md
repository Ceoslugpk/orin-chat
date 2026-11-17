# Advanced search

Advanced search runs on PostgreSQL and does not require an OpenSearch or
Elasticsearch server on self-hosted installations.

## Behavior

When the `advanced_search` account flag is enabled:

- Message results support a date range (`since`, `until`), sender
  (`from=contact:<id>` or `from=agent:<id>`) and inbox filters.
- Conversation and contact results support the date range filters.
- Articles support the updated-at range filters.
- Message text matching uses PostgreSQL `ILIKE` with the existing trigram GIN
  index on `messages.content`. OpenSearch remains an optional extension when
  `OPENSEARCH_URL` is configured; unavailable OpenSearch falls back to SQL.
- Search results stay inside the caller's conversation/inbox permissions and
  the configured search time window.

The dashboard search screen exposes the filters only while the account flag is
on. `advanced_search` is enabled by default for new installations and no longer
marked premium; existing installations keep their saved defaults and opt in
from Super Admin.

`advanced_search_indexing` remains an internal cloud flag and is not required
for self-hosted search.

## Verification

Search service and controller specs cover message/contact/conversation/article
queries, permissions, date/sender/inbox filters, counts and pagination. The
OpenSearch-tagged cases exercise the optional backend when a cluster is
available; the default SQL path is covered without it.
