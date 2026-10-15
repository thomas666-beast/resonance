<script setup lang="ts">
import { useAppStore } from '@/stores/app'

const app = useAppStore()
</script>

<template>
  <footer
    class="shrink-0 border-t border-app bg-surface/90 backdrop-blur-sm
           text-xs text-muted py-2 px-6"
  >
    <div class="max-w-6xl mx-auto flex flex-col sm:flex-row items-center gap-1 sm:gap-4">
      <span>{{ app.info.name }} · © {{ app.info.copyright_year }}</span>
      <span v-if="app.info.admin_contact" class="sm:ml-auto">
        <a
          :href="`mailto:${app.info.admin_contact}`"
          class="hover:text-accent transition-colors"
        >
          {{ app.info.admin_contact }}
        </a>
      </span>
    </div>
  </footer>
</template>
