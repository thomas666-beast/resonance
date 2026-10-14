<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import api from '@/api/client'
import { usePlayerStore, type Track } from '@/stores/player'
import { useFavoritesStore } from '@/stores/favorites'
import TrackRow from '@/components/TrackRow.vue'
import AlbumCover from '@/components/AlbumCover.vue'

const route = useRoute()
const player = usePlayerStore()
const favorites = useFavoritesStore()

const album = ref<any>(null)
const tracks = ref<Track[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    const [albumRes] = await Promise.all([
      api.get(`/albums/${route.params.id}`),
      favorites.loaded ? Promise.resolve() : favorites.load(),
    ])
    album.value = albumRes.data.album
    tracks.value = albumRes.data.tracks
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Failed to load album'
  } finally {
    loading.value = false
  }
})

function playAll() {
  const first = tracks.value[0]
  if (first) player.playTrack(first, tracks.value)
}
</script>

<template>
  <div class="p-8 pb-32 max-w-4xl mx-auto text-app">
    <p v-if="loading" class="text-muted">{{ $t('common.loading') }}</p>
    <p v-else-if="error" class="text-danger">{{ error }}</p>

    <template v-else-if="album">
      <header class="mb-8 flex flex-col sm:flex-row gap-6">
        <AlbumCover
          :album-id="album.id"
          :rounded="false"
          class="!w-48 !h-48 !rounded-xl shadow-2xl"
        />
        <div class="flex flex-col justify-end">
          <p class="text-xs uppercase tracking-widest text-dim mb-2">
            {{ $t('album.label') }}
          </p>
          <h1 class="text-4xl font-semibold tracking-tight">{{ album.title }}</h1>
          <p class="text-muted mt-2">
            <RouterLink v-if="album.artist_id" :to="`/artists/${album.artist_id}`"
                        class="hover:underline">{{ album.artist_name }}</RouterLink>
            <span v-if="album.year"> · {{ album.year }}</span>
            <span v-if="tracks.length"> · {{ $t('album.trackCount', { n: tracks.length }) }}</span>
          </p>
          <button
            @click="playAll"
            :disabled="!tracks.length"
            class="mt-6 self-start px-5 py-2.5 bg-accent text-white rounded-full text-sm
                   font-medium hover:opacity-90 disabled:opacity-40 transition-opacity"
          >
            ▶ {{ $t('album.playAll') }}
          </button>
        </div>
      </header>

      <div class="space-y-0.5">
        <TrackRow
          v-for="(t, i) in tracks"
          :key="t.id"
          :track="t"
          :queue="tracks"
          :index="i + 1"
        />
      </div>
    </template>
  </div>
</template>
