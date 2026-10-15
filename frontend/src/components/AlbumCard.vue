<script setup lang="ts">
import { RouterLink } from 'vue-router'
import AlbumCover from './AlbumCover.vue'

defineProps<{
  album: {
    id: number
    title: string
    year: number | null
    artist_name: string | null
  }
}>()
</script>

<template>
  <RouterLink
    :to="`/albums/${album.id}`"
    class="group w-40 shrink-0 block"
  >
    <div class="aspect-square rounded-xl overflow-hidden shadow-lg
                group-hover:shadow-xl group-hover:-translate-y-1
                active:scale-[0.98] transition-all duration-200 ease-out">
      <AlbumCover :album-id="album.id" fill />
    </div>
    <div class="mt-3">
      <div class="text-sm font-medium truncate text-app">{{ album.title }}</div>
      <div class="text-xs text-muted truncate">
        <template v-if="album.artist_name">{{ album.artist_name }}</template>
        <template v-if="album.artist_name && album.year"> · </template>
        <template v-if="album.year">{{ album.year }}</template>
      </div>
    </div>
  </RouterLink>
</template>
