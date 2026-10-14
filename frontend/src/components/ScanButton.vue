<script setup lang="ts">
import { ref } from 'vue'
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
</script>

<template>
  <button
    @click="trigger"
    :disabled="triggering || scan.scanning"
    class="text-sm px-3 py-1.5 border border-app rounded-full hover-surface
           disabled:opacity-50 transition-colors text-app"
  >
    {{ scan.scanning ? $t('scan.running') : $t('scan.start') }}
  </button>
</template>
