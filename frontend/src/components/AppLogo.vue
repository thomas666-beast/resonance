<script setup lang="ts">
import iconUrl from '@/assets/logo-icon.svg'
import wordmarkRaw from '@/assets/logo-wordmark.svg?raw'

withDefaults(defineProps<{
  variant?: 'icon' | 'wordmark'
  height?: number | string
}>(), {
  variant: 'wordmark',
  height: 28,
})

const px = (v: number | string) => typeof v === 'number' ? v + 'px' : v
</script>

<template>
  <span
    v-if="variant === 'wordmark'"
    class="inline-flex items-center text-app leading-none"
    :style="{ height: px(height) }"
    v-html="wordmarkRaw"
  />
  <img
    v-else
    :src="iconUrl"
    alt="Resonance"
    :style="{ height: px(height) }"
    class="select-none block"
    draggable="false"
  />
</template>

<style scoped>
/* Ensure inline wordmark SVG scales to its container height */
:deep(svg) {
  /* height: 100%; */
  width: auto;
  display: block;
}
</style>
