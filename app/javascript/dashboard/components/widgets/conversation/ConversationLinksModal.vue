<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import ConversationLinksAPI from 'dashboard/api/conversationLinks';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  conversation: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const loading = ref(false);
const links = ref([]);
const candidates = ref([]);
const mergeCandidate = ref(null);
const saving = ref(false);

const conversationId = computed(() => props.conversation?.id);
const contactId = computed(() => props.conversation?.meta?.sender?.id);

const close = () => emit('close');

const load = async () => {
  if (!conversationId.value || !contactId.value) return;

  loading.value = true;
  mergeCandidate.value = null;
  try {
    const [linksResponse, conversationsResponse] = await Promise.all([
      ConversationLinksAPI.get(conversationId.value),
      ContactAPI.getConversations(contactId.value),
    ]);
    links.value = linksResponse.data || [];
    const linked = new Set(links.value.map(link => link.conversation.id));
    candidates.value = (conversationsResponse.data?.payload || []).filter(
      conversation =>
        conversation.id !== conversationId.value && !linked.has(conversation.id)
    );
  } catch (error) {
    useAlert(t('CONVERSATION.HEADER.RELATED.ERROR'));
  } finally {
    loading.value = false;
  }
};

const linkConversation = async conversation => {
  saving.value = true;
  try {
    await ConversationLinksAPI.create(conversationId.value, conversation.id);
    useAlert(t('CONVERSATION.HEADER.RELATED.LINK_SUCCESS'));
    await load();
  } catch (error) {
    useAlert(t('CONVERSATION.HEADER.RELATED.ERROR'));
  } finally {
    saving.value = false;
  }
};

const unlinkConversation = async link => {
  saving.value = true;
  try {
    await ConversationLinksAPI.delete(conversationId.value, link.id);
    useAlert(t('CONVERSATION.HEADER.RELATED.UNLINK_SUCCESS'));
    await load();
  } catch (error) {
    useAlert(t('CONVERSATION.HEADER.RELATED.ERROR'));
  } finally {
    saving.value = false;
  }
};

const confirmMerge = async () => {
  if (!mergeCandidate.value) return;

  saving.value = true;
  const target = mergeCandidate.value;
  try {
    await ConversationLinksAPI.merge(conversationId.value, target.id);
    useAlert(t('CONVERSATION.HEADER.RELATED.MERGE_SUCCESS'));
    close();
    router.push({
      name: 'inbox_conversation',
      params: { accountId: route.params.accountId, conversation_id: target.id },
    });
  } catch (error) {
    useAlert(t('CONVERSATION.HEADER.RELATED.ERROR'));
  } finally {
    saving.value = false;
  }
};

watch(
  () => props.show,
  shown => {
    if (shown) load();
  }
);
</script>

<template>
  <Teleport to="body">
    <div
      v-if="show"
      class="fixed inset-0 z-[100] flex items-center justify-center bg-n-alpha-black2 p-4"
      @click.self="close"
    >
      <div
        class="flex w-full max-w-lg flex-col gap-4 rounded-xl bg-n-solid-2 p-5 shadow-xl"
      >
        <div class="flex items-start justify-between gap-4">
          <div>
            <h3 class="text-heading-2 text-n-slate-12">
              {{ $t('CONVERSATION.HEADER.RELATED.TITLE') }}
            </h3>
            <p class="mb-0 mt-1 text-body-para text-n-slate-11">
              {{ $t('CONVERSATION.HEADER.RELATED.DESCRIPTION') }}
            </p>
          </div>
          <Button
            icon="i-lucide-x"
            size="sm"
            variant="ghost"
            color="slate"
            @click="close"
          />
        </div>

        <div v-if="loading" class="py-6 text-center text-n-slate-11">
          {{ $t('CONVERSATION.HEADER.RELATED.LOADING') }}
        </div>

        <template v-else>
          <div v-if="mergeCandidate" class="rounded-lg bg-n-alpha-2 p-3">
            <p class="mb-2 text-sm font-medium text-n-slate-12">
              {{ $t('CONVERSATION.HEADER.RELATED.CONFIRM_MERGE_TITLE') }}
            </p>
            <p class="mb-3 text-sm text-n-slate-11">
              {{
                $t('CONVERSATION.HEADER.RELATED.CONFIRM_MERGE_DESCRIPTION', {
                  id: mergeCandidate.id,
                })
              }}
            </p>
            <div class="flex justify-end gap-2">
              <Button
                faded
                slate
                sm
                :label="$t('CONVERSATION.HEADER.RELATED.CANCEL')"
                @click="mergeCandidate = null"
              />
              <Button
                color="ruby"
                sm
                :label="$t('CONVERSATION.HEADER.RELATED.CONFIRM_MERGE_BUTTON')"
                :is-loading="saving"
                @click="confirmMerge"
              />
            </div>
          </div>

          <div>
            <h4 class="mb-2 text-sm font-medium text-n-slate-12">
              {{ $t('CONVERSATION.HEADER.RELATED.LINKED_TITLE') }}
            </h4>
            <p v-if="!links.length" class="mb-0 text-sm text-n-slate-11">
              {{ $t('CONVERSATION.HEADER.RELATED.EMPTY_LINKED') }}
            </p>
            <div
              v-for="link in links"
              :key="link.id"
              class="flex items-center justify-between gap-3 border-b border-n-weak py-2 last:border-b-0"
            >
              <div class="min-w-0">
                <div class="truncate text-sm text-n-slate-12">
                  {{
                    `#${link.conversation.id} · ${link.conversation.contact.name}`
                  }}
                </div>
                <div class="truncate text-xs text-n-slate-11">
                  {{ link.conversation.inbox.name }}
                </div>
              </div>
              <Button
                link
                slate
                sm
                :label="$t('CONVERSATION.HEADER.RELATED.UNLINK')"
                :disabled="saving"
                @click="unlinkConversation(link)"
              />
            </div>
          </div>

          <div>
            <h4 class="mb-2 text-sm font-medium text-n-slate-12">
              {{ $t('CONVERSATION.HEADER.RELATED.OTHER_TITLE') }}
            </h4>
            <p v-if="!candidates.length" class="mb-0 text-sm text-n-slate-11">
              {{ $t('CONVERSATION.HEADER.RELATED.EMPTY_OTHER') }}
            </p>
            <div
              v-for="candidate in candidates"
              :key="candidate.id"
              class="flex items-center justify-between gap-3 border-b border-n-weak py-2 last:border-b-0"
            >
              <div class="min-w-0">
                <div class="truncate text-sm text-n-slate-12">
                  {{ `#${candidate.id} · ${candidate.meta.sender.name}` }}
                </div>
                <div class="truncate text-xs text-n-slate-11">
                  {{ candidate.status }}
                </div>
              </div>
              <div class="flex shrink-0 items-center gap-1">
                <Button
                  link
                  slate
                  sm
                  :label="$t('CONVERSATION.HEADER.RELATED.LINK')"
                  :disabled="saving"
                  @click="linkConversation(candidate)"
                />
                <Button
                  link
                  color="ruby"
                  sm
                  :label="$t('CONVERSATION.HEADER.RELATED.MERGE')"
                  :disabled="saving"
                  @click="mergeCandidate = candidate"
                />
              </div>
            </div>
          </div>
        </template>
      </div>
    </div>
  </Teleport>
</template>
