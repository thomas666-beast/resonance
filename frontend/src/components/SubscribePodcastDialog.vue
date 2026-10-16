<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { usePodcastsStore } from '@/stores/podcasts'
import { useToastStore } from '@/stores/toast'
import Modal from './Modal.vue'

const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ (e: 'close'): void; (e: 'subscribed'): void }>()

const { t } = useI18n()
const podcasts = usePodcastsStore()
const toast = useToastStore()

const url    = ref('')
const error  = ref<string | null>(null)
const saving = ref(false)

watch(() => props.open, (open) => {
  if (open) {
    url.value = ''
    error.value = null
    saving.value = false
  }
})

async function submit() {
  error.value = null
  const trimmed = url.value.trim()

  if (!trimmed) {
    error.value = t('podcasts.urlRequired')
    return
  }
  if (!/^https?:\/\//.test(trimmed)) {
    error.value = t('podcasts.invalidUrl')
    return
  }

  saving.value = true
  try {
    await podcasts.subscribe(trimmed)
    toast.success(t('podcasts.subscribed'))
    emit('subscribed')
    emit('close')
  } catch (e: any) {
    error.value = e.response?.data?.error ?? t('toasts.genericError')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Modal :open="open" :title="$t('podcasts.addTitle')" size="md" @close="emit('close')">
    <form @submit.prevent="submit" class="space-y-4">
      <p class="text-sm text-muted leading-relaxed">
        {{ $t('podcasts.addDescription') }}
      </p>

      <label class="block">
        <span class="text-sm text-muted">{{ $t('podcasts.feedUrl') }}</span>
        <input
          v-model="url"
          type="url"
          required
          placeholder="https://feeds.example.com/show.xml"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
      </label>

      <p v-if="error" class="text-danger text-sm">{{ error }}</p>
    </form>

    <template #footer>
      <button
        @click="emit('close')"
        class="px-4 py-2 rounded-full text-sm font-medium border border-app
               hover:bg-surface-2 transition-colors"
      >
        {{ $t('common.cancel') }}
      </button>
      <button
        @click="submit"
        :disabled="saving"
        class="px-4 py-2 rounded-full text-sm font-medium text-white bg-accent
               hover:opacity-90 disabled:opacity-50 transition-opacity"
      >
        {{ saving ? $t('common.loading') : $t('podcasts.subscribe') }}
      </button>
    </template>
  </Modal>
</template>
