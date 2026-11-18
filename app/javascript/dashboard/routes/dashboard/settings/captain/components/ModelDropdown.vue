<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCaptainConfigStore } from 'dashboard/store/captain/preferences';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownBody from 'dashboard/components-next/dropdown-menu/base/DropdownBody.vue';
import DropdownItem from 'dashboard/components-next/dropdown-menu/base/DropdownItem.vue';
import { provideDropdownContext } from 'dashboard/components-next/dropdown-menu/base/provider.js';

const props = defineProps({
  featureKey: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['change']);
const { isOnChatwootCloud } = useAccount();

const inferProvider = modelId => {
  const name = (modelId || '').toLowerCase();
  if (name.startsWith('claude')) return 'anthropic';
  if (name.startsWith('gemini')) return 'gemini';
  return 'openai';
};

const PROVIDER_ICONS = {
  openai: 'i-ri-openai-fill',
  anthropic: 'i-ri-anthropic-line',
  mistral: 'i-logos-mistral-icon',
  gemini: 'i-woot-gemini',
};

const iconForModel = model => {
  return PROVIDER_ICONS[model.provider];
};

const { t } = useI18n();
const captainConfigStore = useCaptainConfigStore();
const isOpen = ref(false);

const availableModels = computed(() =>
  captainConfigStore.getModelsForFeature(props.featureKey)
);

const recommendedModelId = computed(() =>
  captainConfigStore.getDefaultModelForFeature(props.featureKey)
);

const selectedModel = computed(() =>
  captainConfigStore.getSelectedModelForFeature(props.featureKey)
);

const selectedModelId = ref(null);

watch(
  selectedModel,
  newSelected => {
    if (newSelected) {
      selectedModelId.value = newSelected;
    }
  },
  { immediate: true }
);

const selectedModelDetails = computed(() => {
  if (!selectedModelId.value) return null;
  return (
    availableModels.value.find(m => m.id === selectedModelId.value) || null
  );
});

const showCustomModelInput = ref(false);
const customModelDraft = ref('');

const toggleCustomInput = () => {
  showCustomModelInput.value = !showCustomModelInput.value;
  if (showCustomModelInput.value) {
    customModelDraft.value = '';
  }
};

const getCreditLabel = model => {
  const multiplier = model.credit_multiplier || 1;
  return t('CAPTAIN_SETTINGS.MODEL_CONFIG.CREDITS_PER_MESSAGE', {
    credits: multiplier,
  });
};

const toggleDropdown = () => {
  isOpen.value = !isOpen.value;
};

const closeDropdown = () => {
  isOpen.value = false;
};

provideDropdownContext({
  isOpen,
  toggle: () => toggleDropdown(),
  closeMenu: closeDropdown,
});

const selectModel = model => {
  selectedModelId.value = model.id;
  emit('change', { feature: props.featureKey, model: model.id });
  closeDropdown();
};

const applyCustomModel = () => {
  const customModel = customModelDraft.value?.trim();
  if (!customModel) return;
  selectModel({
    id: customModel,
    display_name: customModel,
    provider: inferProvider(customModel),
  });
  showCustomModelInput.value = false;
  customModelDraft.value = '';
};
</script>

<template>
  <div v-on-clickaway="closeDropdown" class="relative flex-shrink-0">
    <button
      type="button"
      class="flex items-center gap-2 px-3 py-2 text-sm border rounded-lg border-n-weak dark:bg-n-solid-2 dark:hover:bg-n-solid-3 bg-n-alpha-2 hover:bg-n-alpha-1 min-w-[180px] justify-between"
      @click="toggleDropdown"
    >
      <span v-if="selectedModelDetails" class="text-n-slate-12">
        {{ selectedModelDetails.display_name }}
      </span>
      <span v-else class="text-n-slate-10">
        {{ t('CAPTAIN_SETTINGS.MODEL_CONFIG.SELECT_MODEL') }}
      </span>
      <Icon
        icon="i-lucide-chevron-down"
        class="size-4 text-n-slate-11 transition-transform"
        :class="{ 'rotate-180': isOpen }"
      />
    </button>
    <DropdownBody
      v-if="isOpen"
      class="absolute right-0 top-full mt-1 min-w-72 z-50 max-h-96 [&>ul]:max-h-96 [&>ul]:overflow-y-scroll"
    >
      <li
        class="n-dropdown-item border-b border-n-weak pb-2 mb-2"
        @mousedown.prevent
      >
        <button
          type="button"
          class="flex w-full items-center justify-between gap-2 px-2 py-1.5 text-sm text-n-slate-11 hover:text-n-slate-12"
          @click="toggleCustomInput"
        >
          <span>{{
            t('CAPTAIN_SETTINGS.MODEL_CONFIG.CUSTOM_MODEL_TOGGLE')
          }}</span>
          <Icon
            :icon="
              showCustomModelInput
                ? 'i-lucide-chevron-up'
                : 'i-lucide-chevron-down'
            "
            class="size-4"
          />
        </button>
        <div v-if="showCustomModelInput" class="px-2 pt-1">
          <Input
            v-model="customModelDraft"
            size="sm"
            :placeholder="
              t('CAPTAIN_SETTINGS.MODEL_CONFIG.CUSTOM_MODEL_PLACEHOLDER')
            "
            @keyup.enter.stop="applyCustomModel"
          />
          <div class="flex justify-end gap-2 mt-2">
            <Button
              slate
              link
              size="xs"
              :label="t('CAPTAIN_SETTINGS.MODEL_CONFIG.CUSTOM_MODEL_CANCEL')"
              @click.stop="showCustomModelInput = false"
            />
            <Button
              blue
              size="xs"
              :label="t('CAPTAIN_SETTINGS.MODEL_CONFIG.CUSTOM_MODEL_APPLY')"
              :disabled="!customModelDraft.trim()"
              @click.stop="applyCustomModel"
            />
          </div>
        </div>
      </li>
      <DropdownItem
        v-for="model in availableModels"
        :key="model.id"
        :click="() => selectModel(model)"
        class="rounded-lg dark:hover:bg-n-solid-3 hover:bg-n-alpha-1"
        :class="{
          'dark:bg-n-solid-3 bg-n-alpha-1': selectedModelId === model.id,
          'pointer-events-none opacity-60': model.coming_soon,
        }"
      >
        <div class="flex gap-2 w-full">
          <Icon :icon="iconForModel(model)" class="size-4 flex-shrink-0" />
          <div class="flex flex-col w-full text-left gap-1">
            <div
              class="text-sm w-full font-medium leading-none text-n-slate-12 flex items-baseline justify-between"
            >
              {{ model.display_name }}
              <span
                v-if="model.id === recommendedModelId"
                class="text-[10px] uppercase text-n-iris-11 border border-1 border-n-iris-10 leading-none rounded-lg px-1 py-0.5"
              >
                {{ t('GENERAL.PREFERRED') }}
              </span>
            </div>
            <span v-if="model.coming_soon" class="text-xs text-n-slate-11">
              {{ t('CAPTAIN_SETTINGS.MODEL_CONFIG.COMING_SOON') }}
            </span>
            <span v-else-if="isOnChatwootCloud" class="text-xs text-n-slate-11">
              {{ getCreditLabel(model) }}
            </span>
          </div>
        </div>
      </DropdownItem>
    </DropdownBody>
  </div>
</template>
