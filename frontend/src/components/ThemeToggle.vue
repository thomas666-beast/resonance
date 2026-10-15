<script setup lang="ts">
import { useThemeStore } from '@/stores/theme'

const theme = useThemeStore()
</script>

<template>
  <button
    @click="theme.toggle()"
    class="w-9 h-9 rounded-full bg-surface-2 border border-app
           flex items-center justify-center text-muted
           hover:text-app hover:border-hi transition-colors"
    :aria-label="`Theme: ${theme.theme}`"
    :title="`Theme: ${theme.theme}`"
  >
    <svg v-if="theme.theme === 'dark'" xmlns="http://www.w3.org/2000/svg"
         viewBox="0 0 24 24" class="w-4 h-4 fill-none"
         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
    </svg>
    <svg v-else-if="theme.theme === 'light'" xmlns="http://www.w3.org/2000/svg"
         viewBox="0 0 24 24" class="w-4 h-4 fill-none"
         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="4"/>
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>
    </svg>
    <svg v-else xmlns="http://www.w3.org/2000/svg"
         viewBox="0 0 24 24" class="w-4 h-4 fill-none"
         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <rect x="2" y="3" width="20" height="14" rx="2"/>
      <path d="M8 21h8M12 17v4"/>
    </svg>
  </button>
</template>
