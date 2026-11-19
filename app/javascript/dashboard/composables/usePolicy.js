import { unref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import {
  getUserPermissions,
  hasPermissions,
} from 'dashboard/helper/permissionsHelper';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';

export function usePolicy() {
  const user = useMapGetter('getCurrentUser');
  const isFeatureEnabled = useMapGetter('accounts/isFeatureEnabledonAccount');
  const isOnChatwootCloud = useMapGetter('globalConfig/isOnChatwootCloud');
  const { accountId } = useAccount();

  const getUserPermissionsForAccount = () => {
    return getUserPermissions(user.value, accountId.value);
  };

  const isFeatureFlagEnabled = featureFlag => {
    if (!featureFlag) return true;
    return isFeatureEnabled.value(accountId.value, featureFlag);
  };

  const checkPermissions = requiredPermissions => {
    if (!requiredPermissions || !requiredPermissions.length) return true;
    const userPermissions = getUserPermissionsForAccount();
    return hasPermissions(requiredPermissions, userPermissions);
  };

  const checkInstallationType = config => {
    if (Array.isArray(config) && config.length > 0) {
      // Orin Chat includes every feature of the enterprise edition; whether a
      // feature shows is decided by its account feature flag alone.
      const installationCheck = {
        [INSTALLATION_TYPES.ENTERPRISE]: true,
        [INSTALLATION_TYPES.CLOUD]: isOnChatwootCloud.value,
        [INSTALLATION_TYPES.COMMUNITY]: true,
      };

      return config.some(type => installationCheck[type]);
    }

    return true;
  };

  // Orin Chat has no paid tiers: a feature shows when the user has the
  // permissions and the account has the feature enabled.
  const shouldShow = (featureFlag, permissions, installationTypes) => {
    if (!checkPermissions(unref(permissions))) return false;
    if (!checkInstallationType(unref(installationTypes))) return false;

    return isFeatureFlagEnabled(unref(featureFlag));
  };

  // Paywalls are never shown. Kept so upstream components can call it.
  const shouldShowPaywall = () => false;

  return {
    checkPermissions,
    checkInstallationType,
    shouldShowPaywall,
    isFeatureFlagEnabled,
    shouldShow,
  };
}
