# SAML SSO

## Settings API

Administrators of accounts with the `saml` feature flag manage settings at
`/api/v1/accounts/:account_id/saml_settings`:

- `GET` returns the settings or `404` when none exist.
- `POST`/`PUT` create or update settings.
- `DELETE` disables SAML for the account.
- `POST .../refresh` re-reads the configured metadata URL.

Two configuration sources are supported:

- **Metadata URL** — the server fetches HTTPS metadata, extracts the
  HTTP-Redirect SSO URL, IdP entity ID and signing certificate, and stores the
  refresh time.
- **Manual fields** — `sso_url`, `idp_entity_id` and a PEM certificate.

Responses include the generated SP entity ID, certificate SHA-256 fingerprint
and ACS URL information used by the dashboard. Metadata fetches require HTTPS
and refuse loopback, private, link-local or multicast addresses.

## Login flow

1. The login SAML form posts the work email to
   `/api/v1/auth/saml_login`.
2. The account is resolved from the explicit `sso_account_id` or from an
   existing user's SAML-enabled account.
3. The server stores the account and optional redirect/mobile target in the
   session and redirects to the OmniAuth SAML request phase.
4. The OmniAuth setup hook loads the account settings into the SAML strategy.
5. After assertion validation, the callback provisions or reuses the user and
   redirects to the normal SSO completion flow.

SAML logins are exempt from email confirmation. JIT provisioning creates an
agent membership by default; role mappings can grant `administrator` when a
configured group is present in the assertion. Existing memberships are not
downgraded.

## Availability

`saml` is enabled by default for new installations and no longer marked
premium. Existing installations keep their saved account flags and opt in from
Super Admin. The SAML login option appears only after at least one account has
stored settings, and the settings page remains account-flag gated.

## Verification

Model, service and request specs cover manual/metadata configuration, HTTPS and
certificate validation, SP entity ID and fingerprint generation, metadata
parsing, settings CRUD/refresh, admin/feature gating, login account resolution,
user provisioning, membership reuse and role mapping. Full IdP assertion
verification requires a real identity provider and is not covered locally.
