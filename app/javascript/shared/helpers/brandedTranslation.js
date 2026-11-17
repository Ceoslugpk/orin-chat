// Replace the upstream and current product names with the installation name
// in every translated message, for every locale. Keep matching case-sensitive
// so identifiers such as `window.$chatwoot` and lowercase URLs stay intact.
const PRODUCT_NAMES = /Chatwoot|Orin Chat/g;

export const brandTranslatedText = (translated, installationName) => {
  if (typeof translated !== 'string' || !installationName) {
    return translated;
  }
  return translated.replace(PRODUCT_NAMES, installationName);
};

export const createBrandedPostTranslation = installationName => {
  return translated => brandTranslatedText(translated, installationName);
};

export const installationNameFromWindow = () => {
  return window.globalConfig?.INSTALLATION_NAME;
};
