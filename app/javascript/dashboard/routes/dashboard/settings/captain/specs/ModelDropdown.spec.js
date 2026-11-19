import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { useCaptainConfigStore } from 'dashboard/store/captain/preferences';
import ModelDropdown from 'dashboard/routes/dashboard/settings/captain/components/ModelDropdown.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ isOnChatwootCloud: false }),
}));

const REMOVE_LABEL = 'CAPTAIN_SETTINGS.MODEL_CONFIG.CUSTOM_MODEL_REMOVE';

const mountDropdown = () => {
  setActivePinia(createPinia());
  const store = useCaptainConfigStore();
  store.features = {
    editor: {
      models: [
        { id: 'gpt-6-luna', provider: 'openai', display_name: 'GPT-6 Luna' },
        {
          id: 'local-llama',
          provider: 'openai',
          display_name: 'local-llama',
        },
      ],
      default: 'gpt-6-luna',
      selected: 'gpt-6-luna',
    },
  };
  store.customModels = [{ id: 'local-llama', provider: 'openai' }];

  const wrapper = mount(ModelDropdown, {
    props: { featureKey: 'editor' },
    global: {
      directives: { 'on-clickaway': {} },
      stubs: { Icon: true },
    },
  });

  return { wrapper, store };
};

const openDropdown = async wrapper => {
  await wrapper.find('button').trigger('click');
};

describe('ModelDropdown custom models', () => {
  it('shows a remove control only for saved custom models', async () => {
    const { wrapper } = mountDropdown();
    await openDropdown(wrapper);

    expect(wrapper.find(`button[aria-label="${REMOVE_LABEL}"]`).exists()).toBe(
      true
    );
    expect(
      wrapper.findAll(`button[aria-label="${REMOVE_LABEL}"]`)
    ).toHaveLength(1);
  });

  it('emits removeCustomModel with the model id', async () => {
    const { wrapper } = mountDropdown();
    await openDropdown(wrapper);

    await wrapper.find(`button[aria-label="${REMOVE_LABEL}"]`).trigger('click');

    expect(wrapper.emitted('removeCustomModel')).toEqual([
      [{ id: 'local-llama', provider: 'openai' }],
    ]);
  });

  it('selecting a catalogue model emits change without saving it', async () => {
    const { wrapper } = mountDropdown();
    await openDropdown(wrapper);

    const catalogueButton = wrapper
      .findAll('.n-dropdown-body button')
      .find(button => button.text().includes('GPT-6 Luna'));
    await catalogueButton.trigger('click');

    expect(wrapper.emitted('change')).toEqual([
      [{ feature: 'editor', model: 'gpt-6-luna' }],
    ]);
    expect(wrapper.emitted('applyCustomModel')).toBeUndefined();
  });
});
