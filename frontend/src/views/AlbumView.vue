<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import api from '@/api/client'
import { usePlayerStore, type Track } from '@/stores/player'
import { useFavoritesStore } from '@/stores/favorites'
import TrackRow from '@/components/TrackRow.vue'
import AlbumCover from '@/components/AlbumCover.vue'
import Skeleton from '@/components/Skeleton.vue'
import SkeletonList from '@/components/SkeletonList.vue'

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
  <div class="p-4 md:p-8 pb-32 max-w-4xl mx-auto text-app">
    <p v-if="error" class="text-danger">{{ error }}</p>

    <div v-else-if="loading" class="space-y-6">
      <div class="flex flex-col sm:flex-row gap-6">
        <Skeleton variant="block" width="12rem" height="12rem" />
        <div class="flex-1 space-y-3 flex flex-col justify-end">
          <Skeleton variant="text" width="30%" height="0.75rem" />
          <Skeleton variant="text" width="60%" height="2.5rem" />
          <Skeleton variant="text" width="40%" height="1rem" />
        </div>
      </div>
      <SkeletonList :count="8" />
    </div>

    <template v-else-if="album">
      <header class="mb-10 flex flex-col md:flex-row gap-6 anim-fade-slide">
        <AlbumCover
          :album-id="album.id"
          :rounded="false"
          class="!w-full md:!w-48 !h-auto md:!h-48 aspect-square !rounded-xl shadow-2xl shrink-0"
        />
        <div class="flex flex-col justify-end">
          <p class="text-label mb-2">{{ $t('album.label') }}</p>
          <h1 class="text-display">{{ album.title }}</h1>
          <p class="text-muted mt-3">
            <RouterLink v-if="album.artist_id" :to="`/artists/${album.artist_id}`"
                        class="hover:underline text-accent">{{ album.artist_name }}</RouterLink>
            <span v-if="album.year" class="mx-1">·</span>
            <span v-if="album.year">{{ album.year }}</span>
            <span v-if="tracks.length" class="mx-1">·</span>
            <span v-if="tracks.length">{{ $t('album.trackCount', { n: tracks.length }) }}</span>
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
        <div
          v-for="(t, i) in tracks"
          :key="t.id"
          class="anim-fade-slide"
          :style="{ animationDelay: Math.min(i, 12) * 25 + 'ms' }"
        >
          <TrackRow
            :track="t"
            :queue="tracks"
            :index="i + 1"
          />
        </div>
      </div>
    </template>
  </div>
</template>
