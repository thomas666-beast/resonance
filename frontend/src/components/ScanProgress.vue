<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useScanStore } from '@/stores/scan'

const { t } = useI18n()
const scan = useScanStore()
</script>

<template>
  <div
    v-if="scan.scanning || scan.reconciling"
    class="bg-surface-2 text-app text-sm px-6 py-2 flex items-center gap-4 border-b border-app"
  >
    <span class="font-medium">
      {{ scan.reconciling ? $t('scan.reconciling') : $t('scan.running') }}
    </span>

    <div v-if="!scan.reconciling" class="flex-1 bg-surface h-1.5 rounded overflow-hidden">
      <div
        class="bg-accent h-full transition-all"
        :style="{ width: scan.percent + '%' }"
      />
    </div>
    <div v-else class="flex-1 bg-surface h-1.5 rounded overflow-hidden">
      <div class="bg-accent h-full w-1/3 animate-pulse" />
    </div>

    <span v-if="!scan.reconciling" class="text-xs tabular-nums text-muted">
      {{ scan.processed }} / {{ scan.total }}
    </span>
    <span v-else class="text-xs text-muted">…</span>
  </div>
</template>
