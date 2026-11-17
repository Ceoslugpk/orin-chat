import { mount } from '@vue/test-utils';
import SLAUnavailable from '../SLAUnavailable.vue';
import messages from 'dashboard/i18n/locale/en/sla.json';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('SLA unavailable state', () => {
  it('explains that tracking is not implemented without an upgrade path', () => {
    const wrapper = mount(SLAUnavailable);

    expect(wrapper.text()).toContain('SLA.UNAVAILABLE.TITLE');
    expect(wrapper.text()).toContain('SLA.UNAVAILABLE.DESCRIPTION');
    expect(wrapper.find('a').exists()).toBe(false);
    expect(wrapper.find('button').exists()).toBe(false);
    expect(messages.SLA.UNAVAILABLE.DESCRIPTION).toContain(
      'No upgrade is required.'
    );
  });
});
