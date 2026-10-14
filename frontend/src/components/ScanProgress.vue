<script setup lang="ts">
import { useScanStore } from '@/stores/scan'

const scan = useScanStore()
</script>

<template>
  <div
    v-if="scan.scanning"
    class="bg-surface-2 text-app text-sm px-6 py-2 flex items-center gap-4 border-b border-app"
  >
    <span class="font-medium">{{ $t('scan.running') }}</span>
    <div class="flex-1 bg-surface h-1.5 rounded overflow-hidden">
      <div
        class="bg-accent h-full transition-all"
        :style="{ width: scan.percent + '%' }"
      />
    </div>
    <span class="text-xs tabular-nums text-muted">
      {{ scan.processed }} / {{ scan.total }}
    </span>
  </div>
</template>
