import { createI18n } from 'vue-i18n';
import {
  brandTranslatedText,
  createBrandedPostTranslation,
  installationNameFromWindow,
} from '../brandedTranslation';

describe('brandTranslatedText', () => {
  it('replaces every occurrence of the upstream product name', () => {
    expect(
      brandTranslatedText('Login to Chatwoot. Chatwoot is ready.', 'Orin Chat')
    ).toBe('Login to Orin Chat. Orin Chat is ready.');
  });

  it('replaces the Orin Chat product name for white-labelled installations', () => {
    expect(brandTranslatedText('Orin Chat is ready.', 'Acme')).toBe(
      'Acme is ready.'
    );
  });

  it('keeps lowercase identifiers and URLs intact', () => {
    expect(
      brandTranslatedText(
        'Call window.$chatwoot.toggle() — see https://chatwoot.com',
        'Orin Chat'
      )
    ).toBe('Call window.$chatwoot.toggle() — see https://chatwoot.com');
  });

  it('returns the text unchanged without an installation name', () => {
    expect(brandTranslatedText('Login to Chatwoot', undefined)).toBe(
      'Login to Chatwoot'
    );
  });

  it('returns non-string messages unchanged', () => {
    const nodes = [{ type: 'vnode' }];
    expect(brandTranslatedText(nodes, 'Orin Chat')).toBe(nodes);
  });
});

describe('createBrandedPostTranslation', () => {
  it('brands messages translated through vue-i18n in any locale', () => {
    const i18n = createI18n({
      legacy: false,
      locale: 'fr',
      fallbackLocale: 'en',
      messages: {
        en: { TITLE: 'Login to Chatwoot' },
        fr: { TITLE: 'Se connecter à Chatwoot' },
      },
      postTranslation: createBrandedPostTranslation('Orin Chat'),
    });

    expect(i18n.global.t('TITLE')).toBe('Se connecter à Orin Chat');
  });
});

describe('installationNameFromWindow', () => {
  afterEach(() => {
    delete window.globalConfig;
  });

  it('reads the installation name from the server-rendered global config', () => {
    window.globalConfig = { INSTALLATION_NAME: 'Orin Chat' };
    expect(installationNameFromWindow()).toBe('Orin Chat');
  });

  it('returns undefined when the global config is missing', () => {
    expect(installationNameFromWindow()).toBeUndefined();
  });
});
