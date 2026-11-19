import { ref } from 'vue';
import { usePolicy } from '../usePolicy';
import { useMapGetter } from 'dashboard/composables/store';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';

vi.mock('dashboard/composables/store', () => ({ useMapGetter: vi.fn() }));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(1) }),
}));

const mockGetters = ({ enabledFlags = [], role = 'administrator' } = {}) => {
  const getters = {
    getCurrentUser: ref({
      accounts: [{ id: 1, role, permissions: [role] }],
    }),
    'accounts/isFeatureEnabledonAccount': ref((_accountId, flag) =>
      enabledFlags.includes(flag)
    ),
    'globalConfig/isOnChatwootCloud': ref(false),
  };
  useMapGetter.mockImplementation(name => getters[name]);
};

describe('usePolicy', () => {
  it('shows a feature only when its account flag is enabled', () => {
    mockGetters({ enabledFlags: ['audit_logs'] });
    const { shouldShow } = usePolicy();

    expect(shouldShow('audit_logs', ['administrator'])).toBe(true);
    expect(shouldShow('sla', ['administrator'])).toBe(false);
  });

  it('hides a feature when the user lacks the permission', () => {
    mockGetters({ enabledFlags: ['audit_logs'], role: 'agent' });
    const { shouldShow } = usePolicy();

    expect(shouldShow('audit_logs', ['administrator'])).toBe(false);
  });

  it('includes enterprise-edition features on every installation', () => {
    mockGetters({ enabledFlags: ['audit_logs'] });
    const { shouldShow } = usePolicy();

    expect(
      shouldShow(
        'audit_logs',
        ['administrator'],
        [INSTALLATION_TYPES.ENTERPRISE]
      )
    ).toBe(true);
  });

  it('keeps Chatwoot Cloud-only screens hidden', () => {
    mockGetters({ enabledFlags: ['audit_logs'] });
    const { checkInstallationType } = usePolicy();

    expect(checkInstallationType([INSTALLATION_TYPES.CLOUD])).toBe(false);
  });

  it('never shows a paywall', () => {
    mockGetters();
    const { shouldShowPaywall } = usePolicy();

    expect(shouldShowPaywall('sla')).toBe(false);
    expect(shouldShowPaywall('companies')).toBe(false);
  });
});
