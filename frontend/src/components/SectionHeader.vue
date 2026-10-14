<script setup lang="ts">
import { RouterLink } from 'vue-router'

defineProps<{
  title: string
  moreLabel?: string
  moreTo?: string
}>()
</script>

<template>
  <div class="flex items-baseline justify-between mb-4">
    <h2 class="text-xl font-semibold tracking-tight text-app">{{ title }}</h2>
    <RouterLink
      v-if="moreLabel && moreTo"
      :to="moreTo"
      class="text-sm text-muted hover:text-accent transition-colors"
    >
      {{ moreLabel }} →
    </RouterLink>
  </div>
</template>
