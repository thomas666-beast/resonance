<script setup lang="ts">
withDefaults(defineProps<{
  icon?: string
  title: string
  description?: string
  actionLabel?: string
  actionTo?: string
}>(), {
  icon: 'music',
})

const ICONS: Record<string, string> = {
  music:  'M9 18V5l12-2v13M6 21a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM18 19a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  album:  'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zM12 14a2 2 0 1 1 0-4 2 2 0 0 1 0 4z',
  artist: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  heart:  'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z',
  list:   'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
}
</script>

<template>
  <div class="flex flex-col items-center justify-center text-center py-16 px-6">
    <div class="w-16 h-16 rounded-full bg-surface-2 flex items-center justify-center mb-4">
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
           class="w-8 h-8 fill-none stroke-muted" stroke-width="1.75"
           stroke-linecap="round" stroke-linejoin="round">
        <path :d="ICONS[icon] ?? ICONS.music" />
      </svg>
    </div>

    <h2 class="text-lg font-semibold text-app mb-1">{{ title }}</h2>
    <p v-if="description" class="text-sm text-muted max-w-sm mb-5">{{ description }}</p>

    <RouterLink
      v-if="actionLabel && actionTo"
      :to="actionTo"
      class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
             hover:opacity-90 transition-opacity"
    >
      {{ actionLabel }}
    </RouterLink>
  </div>
</template>
