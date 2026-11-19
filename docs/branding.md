# Branding and white-labelling

## Installation branding

Super Admin → Settings → Custom Branding opens the installation branding form
(`/super_admin/app_config?config=branding`). It edits the installation-wide
values used by the dashboard, widget, help center, survey, and emails:

- `INSTALLATION_NAME`
- `BRAND_NAME`
- `BRAND_URL`
- `WIDGET_BRAND_URL`
- `LOGO`, `LOGO_DARK`, `LOGO_THUMBNAIL`

The form uses the existing installation-config persistence and accepts logo
paths or URLs. User-facing translations are post-processed at runtime, so the
configured installation name replaces upstream product names in every locale.

## Per-account “Powered by” control

`settings.disable_branding` controls the branding footer for an account. It
defaults to `true`, so **branding is hidden by default** for new and existing
accounts that have not opted in. Account administrators can change it under
Settings → Account → Branding (“Hide Powered by branding”). The same setting
drives:

- the web widget footer,
- help-center/portal footers and their social links,
- CSAT survey responses.

The legacy `disable_branding` account feature flag is deprecated and no longer
read; the setting is the single source of truth. Transactional email footers
retain the installation brand as legal attribution.

## Signup terms and privacy links

Signup locale strings now use `__TERMS_URL__` and `__PRIVACY_URL__` placeholders
instead of upstream URLs. They resolve from `TERMS_URL` / `PRIVACY_URL`
installation configuration, so no upstream legal links are shown.

## Integration availability

Supported integrations no longer default to off: Stripe, Linear, Notion, CRM,
Shopify, and Shopify custom apps are enabled for new installations and remain
subject to their own external configuration checks. Existing installations
retain saved account flags and opt in from Super Admin. Unimplemented or
cloud-only backends (Captain, voice calls, CSAT review-note editing, advanced
BI reporting) stay disabled rather than showing upgrade paths.

## Verification

Account settings/API and widget config specs cover the default-off branding
decision and per-account override. Super Admin app-config specs cover the
branding form. The dashboard bundle builds with the new settings section.
