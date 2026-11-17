<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Switch from 'next/switch/Switch.vue';
import SectionLayout from './SectionLayout.vue';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();
const isSaving = ref(false);

const disableBranding = computed(
  () => currentAccount.value?.settings?.disable_branding ?? true
);

const toggleBranding = async value => {
  isSaving.value = true;
  try {
    await updateAccount({ disable_branding: value }, { silent: true });
    useAlert(t('GENERAL_SETTINGS.FORM.BRANDING.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.BRANDING.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <SectionLayout
    :title="$t('GENERAL_SETTINGS.FORM.BRANDING.TITLE')"
    :description="$t('GENERAL_SETTINGS.FORM.BRANDING.NOTE')"
    with-border
  >
    <div class="flex items-center justify-between gap-4">
      <p class="mb-0 text-body-main text-n-slate-11">
        {{ $t('GENERAL_SETTINGS.FORM.BRANDING.LABEL') }}
      </p>
      <Switch
        :model-value="disableBranding"
        :disabled="isSaving"
        @change="toggleBranding"
      />
    </div>
  </SectionLayout>
</template>
