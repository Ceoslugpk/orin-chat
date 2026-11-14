// Upstream locale strings name the product "Chatwoot". Replace that name with
// the installation name in every translated message, for every locale, so
// Orin Chat (or any white-labelled installation) shows its own name without
// editing translation files. Only the capitalised product name is replaced,
// so identifiers such as `window.$chatwoot` or URLs stay intact.
const UPSTREAM_PRODUCT_NAME = /Chatwoot/g;

export const brandTranslatedText = (translated, installationName) => {
  if (typeof translated !== 'string' || !installationName) {
    return translated;
  }
  return translated.replace(UPSTREAM_PRODUCT_NAME, installationName);
};

export const createBrandedPostTranslation = installationName => {
  return translated => brandTranslatedText(translated, installationName);
};

export const installationNameFromWindow = () => {
  return window.globalConfig?.INSTALLATION_NAME;
};
