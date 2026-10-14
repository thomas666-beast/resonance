<script setup lang="ts">
withDefaults(defineProps<{
  variant?: 'text' | 'circle' | 'block'
  width?: string
  height?: string
}>(), {
  variant: 'block',
  width: '100%',
  height: '1rem',
})
</script>

<template>
  <div
    class="animate-pulse bg-surface-2"
    :class="{
      'rounded': variant === 'text',
      'rounded-full': variant === 'circle',
      'rounded-lg': variant === 'block',
    }"
    :style="{ width, height }"
  />
</template>
