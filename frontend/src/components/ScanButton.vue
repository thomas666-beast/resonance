<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import api from '@/api/client'
import { useScanStore } from '@/stores/scan'

const { t } = useI18n()
const scan = useScanStore()
const triggering = ref(false)

async function trigger() {
  triggering.value = true
  try {
    await api.post('/scan', {})
  } finally {
    triggering.value = false
  }
}
</script>

<template>
  <button
    @click="trigger"
    :disabled="triggering || scan.scanning"
    class="text-sm px-3 py-1 border rounded hover:bg-gray-100 disabled:opacity-50"
  >
    {{ scan.scanning ? $t('scan.running') : $t('scan.start') }}
  </button>
</template>
