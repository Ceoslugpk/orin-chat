import { shallowMount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import EditAgent from '../EditAgent.vue';

const dispatch = vi.fn();
const platformState = vi.hoisted(() => ({ customRolesEnabled: true }));
const definitions = [
  { id: 91, name: 'Reporting', permissions: ['report_manage'] },
  { id: 92, name: 'Contacts', permissions: ['contact_manage'] },
  { id: 93, name: 'Reporting', permissions: ['conversation_manage'] },
];

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: name => {
    if (name === 'customRole/getCustomRoles') return ref(definitions);
    if (name === 'accounts/isFeatureEnabledonAccount') {
      return ref(() => platformState.customRolesEnabled);
    }
    if (name === 'getCurrentAccountId') return ref(1);
    return ref({});
  },
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${params.name} (#${params.id})` : key),
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const mountEditor = (props = {}) =>
  shallowMount(EditAgent, {
    props: {
      id: 1,
      name: 'Existing agent',
      type: 'agent',
      availability: 'offline',
      provider: 'saml',
      ...props,
    },
    global: {
      mocks: { $t: key => key },
      stubs: { 'woot-modal-header': true },
    },
  });

const submit = async wrapper => {
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dispatch).toHaveBeenCalledWith('agents/update', expect.any(Object));
  return dispatch.mock.calls[0][1];
};

describe('Agent editor role intent', () => {
  beforeEach(() => {
    dispatch.mockReset();
    platformState.customRolesEnabled = true;
  });

  it('hides custom role options when the account feature is disabled', () => {
    platformState.customRolesEnabled = false;

    const options = mountEditor()
      .findAll('select')[0]
      .findAll('option')
      .map(option => option.text());

    expect(options).toEqual([
      'AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR',
      'AGENT_MGMT.AGENT_TYPES.AGENT',
    ]);
  });

  it('preserves inactive stored metadata on an unrelated edit when the feature is disabled', async () => {
    platformState.customRolesEnabled = false;

    const payload = await submit(mountEditor({ customRoleId: 91 }));

    expect(payload.role).toBe('agent');
    expect(payload).not.toHaveProperty('custom_role_id');
  });

  it('clears inactive stored metadata when the built-in role changes', async () => {
    platformState.customRolesEnabled = false;
    const wrapper = mountEditor({ customRoleId: 91 });

    await wrapper.findAll('select')[0].setValue('administrator');
    const payload = await submit(wrapper);

    expect(payload.role).toBe('administrator');
    expect(payload.custom_role_id).toBeNull();
  });

  it('labels duplicate custom role definitions distinctly', () => {
    const options = mountEditor()
      .findAll('select')[0]
      .findAll('option')
      .map(option => option.text());

    expect(options).toEqual([
      'AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR',
      'AGENT_MGMT.AGENT_TYPES.AGENT',
      'Reporting (#91)',
      'Contacts',
      'Reporting (#93)',
    ]);
  });

  it('omits a role clear on an unrelated built-in-agent edit', async () => {
    const payload = await submit(mountEditor());

    expect(payload.role).toBe('agent');
    expect(payload).not.toHaveProperty('custom_role_id');
  });

  it('explicitly clears stored metadata on a built-in role change', async () => {
    const wrapper = mountEditor();
    await wrapper.findAll('select')[0].setValue('administrator');

    const payload = await submit(wrapper);

    expect(payload.role).toBe('administrator');
    expect(payload.custom_role_id).toBeNull();
  });

  it('explicitly clears a known stored definition when selecting the standard agent role', async () => {
    const wrapper = mountEditor({ customRoleId: 91 });
    await wrapper.findAll('select')[0].setValue('agent');

    const payload = await submit(wrapper);

    expect(payload.custom_role_id).toBeNull();
  });

  it('does not resend an unchanged stored custom-role assignment', async () => {
    const payload = await submit(mountEditor({ customRoleId: 91 }));

    expect(payload).not.toHaveProperty('custom_role_id');
    expect(payload).not.toHaveProperty('role');
  });

  it('sends a newly selected definition to the guarded API', async () => {
    const wrapper = mountEditor({ customRoleId: 91 });
    await wrapper.findAll('select')[0].setValue('92');

    const payload = await submit(wrapper);

    expect(payload.custom_role_id).toBe(92);
  });
});
