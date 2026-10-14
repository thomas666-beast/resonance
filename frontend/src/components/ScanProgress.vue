<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useScanStore } from '@/stores/scan'

const { t } = useI18n()
const scan = useScanStore()
</script>

<template>
  <div
    v-if="scan.scanning"
    class="bg-black text-white text-sm px-6 py-2 flex items-center gap-4"
  >
    <span class="font-medium">{{ $t('scan.running') }}</span>
    <div class="flex-1 bg-gray-700 h-1.5 rounded overflow-hidden">
      <div
        class="bg-white h-full transition-all"
        :style="{ width: scan.percent + '%' }"
      />
    </div>
    <span class="text-xs tabular-nums">
      {{ scan.processed }} / {{ scan.total }}
    </span>
  </div>
</template>
