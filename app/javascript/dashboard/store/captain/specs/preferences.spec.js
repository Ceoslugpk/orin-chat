import { createPinia, setActivePinia } from 'pinia';
import CaptainPreferencesAPI from 'dashboard/api/captain/preferences';
import { useCaptainConfigStore } from '../preferences';

vi.mock('dashboard/api/captain/preferences', () => ({
  default: {
    get: vi.fn(),
    updatePreferences: vi.fn(),
  },
}));

const preferencesResponse = {
  data: {
    providers: { openai: { display_name: 'OpenAI' } },
    models: { 'gpt-6-luna': { provider: 'openai' } },
    custom_models: [
      { id: 'local-llama', provider: 'openai', display_name: 'local-llama' },
    ],
    provider_configured: { openai: true, anthropic: false, gemini: false },
    features: {
      editor: {
        models: [{ id: 'gpt-6-luna', provider: 'openai' }],
        default: 'gpt-6-luna',
        selected: 'local-llama',
      },
    },
  },
};

describe('useCaptainConfigStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('stores the custom model library and provider availability on fetch', async () => {
    CaptainPreferencesAPI.get.mockResolvedValue(preferencesResponse);

    const store = useCaptainConfigStore();
    await store.fetch();

    expect(store.getCustomModels).toEqual([
      { id: 'local-llama', provider: 'openai', display_name: 'local-llama' },
    ]);
    expect(store.isProviderConfigured('openai')).toBe(true);
    expect(store.isProviderConfigured('anthropic')).toBe(false);
  });

  it('keeps the custom model library after a preference update', async () => {
    CaptainPreferencesAPI.updatePreferences.mockResolvedValue(
      preferencesResponse
    );

    const store = useCaptainConfigStore();
    await store.updatePreferences({ captain_custom_models: [] });

    expect(CaptainPreferencesAPI.updatePreferences).toHaveBeenCalledWith({
      captain_custom_models: [],
    });
    expect(store.getCustomModels).toHaveLength(1);
  });

  it('treats a provider with no availability data as configured', () => {
    const store = useCaptainConfigStore();

    expect(store.isProviderConfigured('openai')).toBe(true);
  });
});
