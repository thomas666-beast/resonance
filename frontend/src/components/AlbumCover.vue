<script setup lang="ts">
import { ref, computed } from 'vue'

const props = withDefaults(defineProps<{
  albumId: number
  size?: 'sm' | 'md' | 'lg'
  rounded?: boolean
  fill?: boolean
}>(), {
  size: 'md',
  rounded: false,
  fill: false,
})

const failed = ref(false)

const src = computed(() => {
  const token = (window as any).__resonance_access_token ?? ''
  return `/api/cover/${props.albumId}?token=${encodeURIComponent(token)}`
})

const sizeClass = computed(() => {
  if (props.fill) return 'w-full h-full'
  return { sm: 'w-10 h-10', md: 'w-14 h-14', lg: 'w-16 h-16' }[props.size]
})

const roundedClass = computed(() =>
  props.rounded ? 'rounded-md' : 'rounded-lg'
)
</script>

<template>
  <div
    :class="[
      sizeClass,
      roundedClass,
      'bg-surface-2 overflow-hidden flex items-center justify-center shrink-0'
    ]"
  >
    <img
      v-if="!failed"
      :src="src"
      @error="failed = true"
      class="w-full h-full object-cover"
      alt=""
    />
    <svg
      v-else
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      class="w-1/2 h-1/2 fill-none stroke-muted"
      stroke-width="1.5"
    >
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="2" />
    </svg>
  </div>
</template>
