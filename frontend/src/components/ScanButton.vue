<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import api from '@/api/client'
import { useScanStore } from '@/stores/scan'
import { useToastStore } from '@/stores/toast'

const { t } = useI18n()
const scan = useScanStore()
const toast = useToastStore()
const triggering = ref(false)

async function trigger() {
  triggering.value = true
  try {
    await api.post('/scan', {})
  } catch {
    toast.error(t('toasts.genericError'))
  } finally {
    triggering.value = false
  }
}

// Fire a summary toast when a scan finishes
watch(() => scan.lastResult, (r) => {
  if (!r) return
  if (r.missing > 0) {
    toast.info(t('scan.doneWithMissing', {
      inserted: r.inserted,
      missing:  r.missing,
    }))
  } else {
    toast.success(t('scan.done', {
      inserted: r.inserted,
      updated:  r.updated,
    }))
  }
})
</script>

<template>
  <button
    @click="trigger"
    :disabled="triggering || scan.scanning || scan.reconciling"
    class="h-9 px-4 rounded-full text-sm font-medium text-app
           bg-surface-2 border border-app
           hover:border-hi disabled:opacity-50 transition-colors"
  >
    {{ (scan.scanning || scan.reconciling) ? $t('scan.running') : $t('scan.start') }}
  </button>
</template>
