<script setup lang="ts">
import { computed, ref } from 'vue'
import { useFavoritesStore } from '@/stores/favorites'

const props = defineProps<{ trackId: number }>()
const favorites = useFavoritesStore()

const popping = ref(false)
const filled = computed(() => favorites.isFavorited(props.trackId))

async function onClick(e: MouseEvent) {
  e.stopPropagation()
  popping.value = false
  // retrigger animation on next tick
  requestAnimationFrame(() => { popping.value = true })
  setTimeout(() => { popping.value = false }, 320)
  await favorites.toggle(props.trackId)
}
</script>

<template>
  <button
    @click="onClick"
    :aria-label="filled ? 'Unfavorite' : 'Favorite'"
    :aria-pressed="filled"
    class="p-1.5 rounded-full hover:bg-stone-100 transition-colors"
    :class="{ 'heart-pop': popping }"
  >
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      class="w-5 h-5 transition-colors"
      :class="filled ? 'fill-amber-500 stroke-amber-500' : 'fill-none stroke-stone-400'"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" />
    </svg>
  </button>
</template>
