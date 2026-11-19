import { mount } from '@vue/test-utils';
import CustomRolePreview from '../CustomRolePaywall.vue';
import messages from 'dashboard/i18n/locale/en/customRole.json';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('Custom role preview', () => {
  it('explains that the account feature is off without an upgrade link', () => {
    const wrapper = mount(CustomRolePreview);

    expect(wrapper.text()).toContain('CUSTOM_ROLE.PREVIEW.TITLE');
    expect(wrapper.text()).toContain('CUSTOM_ROLE.PREVIEW.DESCRIPTION');
    expect(wrapper.find('a').exists()).toBe(false);
    expect(wrapper.find('button').exists()).toBe(false);
    expect(wrapper.find('table').exists()).toBe(false);
    expect(messages.CUSTOM_ROLE.PREVIEW.DESCRIPTION).toContain(
      'An installation administrator can enable them for this account'
    );
    expect(messages.CUSTOM_ROLE.PREVIEW.DESCRIPTION).toContain(
      'no upgrade is required.'
    );
  });
});
