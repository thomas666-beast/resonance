<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import api from '@/api/client'
import { usePlayerStore, type Track } from '@/stores/player'

const route = useRoute()
const player = usePlayerStore()

const album = ref<any>(null)
const tracks = ref<Track[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    const { data } = await api.get(`/albums/${route.params.id}`)
    album.value = data.album
    tracks.value = data.tracks
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Failed to load album'
  } finally {
    loading.value = false
  }
})

function play(track: Track) {
  player.playTrack(track, tracks.value)
}

function fmt(ms: number | null): string {
  if (!ms) return '—'
  const s = Math.floor(ms / 1000)
  return `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, '0')}`
}

const isCurrent = (t: Track) => player.current?.id === t.id
</script>

<template>
  <div class="p-8 pb-32">
    <p v-if="loading">Loading…</p>
    <p v-else-if="error" class="text-red-600">{{ error }}</p>
    <template v-else-if="album">
      <h1 class="text-3xl font-bold">{{ album.title }}</h1>
      <p class="text-gray-600 mb-6">
        <RouterLink v-if="album.artist_id" :to="`/artists/${album.artist_id}`" class="hover:underline">
          {{ album.artist_name }}
        </RouterLink>
        <span v-if="album.year"> · {{ album.year }}</span>
      </p>

      <ul class="divide-y">
        <li
          v-for="t in tracks"
          :key="t.id"
          class="flex items-center gap-4 py-2 cursor-pointer hover:bg-gray-100 px-2 rounded"
          :class="{ 'bg-gray-100': isCurrent(t) }"
          @click="play(t)"
        >
          <span class="w-8 text-right text-gray-500">{{ t.track_number ?? '·' }}</span>
          <span class="flex-1">{{ t.title }}</span>
          <span class="text-gray-500 text-sm">{{ fmt(t.duration_ms) }}</span>
        </li>
      </ul>
    </template>
  </div>
</template>
