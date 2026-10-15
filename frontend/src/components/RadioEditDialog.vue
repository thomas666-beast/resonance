<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRadioStore, type RadioStation } from '@/stores/radio'
import { useToastStore } from '@/stores/toast'
import Modal from './Modal.vue'

const props = defineProps<{
  open: boolean
  station?: RadioStation | null
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'saved'): void
}>()

const { t } = useI18n()
const radio = useRadioStore()
const toast = useToastStore()

const editing = computed(() => !!props.station?.id)

const name         = ref('')
const streamUrl    = ref('')
const homepageUrl  = ref('')
const logoUrl      = ref('')
const genre        = ref('')
const bitrate      = ref<number | string>('')
const isPublic     = ref(true)
const error        = ref<string | null>(null)
const saving       = ref(false)

watch(() => props.open, (open) => {
  if (!open) return
  const s = props.station
  name.value        = s?.name ?? ''
  streamUrl.value   = s?.stream_url ?? ''
  homepageUrl.value = s?.homepage_url ?? ''
  logoUrl.value     = s?.logo_url ?? ''
  genre.value       = s?.genre ?? ''
  bitrate.value     = s?.bitrate ?? ''
  isPublic.value    = s?.is_public ?? true
  error.value       = null
  saving.value      = false
})

async function submit() {
  error.value = null

  if (!name.value.trim()) {
    error.value = t('radio.nameRequired')
    return
  }
  if (!/^https?:\/\//.test(streamUrl.value.trim())) {
    error.value = t('radio.invalidUrl')
    return
  }

  const payload = {
    name:         name.value.trim(),
    stream_url:   streamUrl.value.trim(),
    homepage_url: homepageUrl.value.trim() || null,
    logo_url:     logoUrl.value.trim()     || null,
    genre:        genre.value.trim()       || null,
    bitrate:      bitrate.value === '' ? null : Number(bitrate.value),
    is_public:    isPublic.value,
  }

  saving.value = true
  try {
    if (editing.value && props.station) {
      await radio.update(props.station.id, payload)
      toast.success(t('radio.updated'))
    } else {
      await radio.create(payload)
      toast.success(t('radio.created'))
    }
    emit('saved')
    emit('close')
  } catch (e: any) {
    error.value = e.response?.data?.error ?? t('toasts.genericError')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Modal
    :open="open"
    :title="editing ? $t('radio.edit') : $t('radio.add')"
    size="md"
    @close="emit('close')"
  >
    <form @submit.prevent="submit" class="space-y-4">
      <label class="block">
        <span class="text-sm text-muted">{{ $t('radio.name') }}</span>
        <input
          v-model="name"
          type="text"
          required
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
      </label>

      <label class="block">
        <span class="text-sm text-muted">{{ $t('radio.streamUrl') }}</span>
        <input
          v-model="streamUrl"
          type="url"
          required
          :placeholder="$t('radio.urlPlaceholder')"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
        <span class="text-xs text-dim mt-1 block">{{ $t('radio.urlHint') }}</span>
      </label>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <label class="block">
          <span class="text-sm text-muted">{{ $t('radio.genre') }}</span>
          <input
            v-model="genre"
            type="text"
            class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                   px-3 py-2 focus:outline-none focus:border-accent"
          />
        </label>

        <label class="block">
          <span class="text-sm text-muted">{{ $t('radio.bitrate') }}</span>
          <input
            v-model="bitrate"
            type="number"
            min="0"
            class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                   px-3 py-2 focus:outline-none focus:border-accent"
          />
        </label>
      </div>

      <label class="block">
        <span class="text-sm text-muted">{{ $t('radio.homepageUrl') }}</span>
        <input
          v-model="homepageUrl"
          type="url"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
      </label>

      <label class="block">
        <span class="text-sm text-muted">{{ $t('radio.logoUrl') }}</span>
        <input
          v-model="logoUrl"
          type="url"
          class="mt-1 w-full border border-app bg-surface-2 text-app rounded-lg
                 px-3 py-2 focus:outline-none focus:border-accent"
        />
      </label>

      <label class="flex items-center gap-3 cursor-pointer">
        <input v-model="isPublic" type="checkbox"
               class="w-4 h-4 accent-[var(--accent)]" />
        <span class="text-sm text-app">{{ $t('radio.publicStation') }}</span>
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
        {{ saving ? $t('common.loading') : $t('common.save') }}
      </button>
    </template>
  </Modal>
</template>
