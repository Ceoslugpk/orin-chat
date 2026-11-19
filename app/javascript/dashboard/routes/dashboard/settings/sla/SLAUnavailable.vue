<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
</script>

<template>
  <div class="w-full min-h-[12rem] flex flex-col gap-2 text-n-slate-11">
    <p class="text-heading-3 text-n-slate-12">
      {{ t('SLA.UNAVAILABLE.TITLE') }}
    </p>
    <p class="text-body-main">
      {{ t('SLA.UNAVAILABLE.DESCRIPTION') }}
    </p>
  </div>
</template>
