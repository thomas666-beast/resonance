<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import api from '@/api/client'
import { useAuthStore } from '@/stores/auth'
import type { Track } from '@/stores/player'
import TrackCard from '@/components/TrackCard.vue'
import AlbumCard from '@/components/AlbumCard.vue'
import SectionHeader from '@/components/SectionHeader.vue'
import Skeleton from '@/components/Skeleton.vue'

interface AlbumCardData {
  id: number
  title: string
  year: number | null
  artist_name: string | null
}

interface PlaylistCard {
  id: number
  name: string
  track_count: number
}

const auth = useAuthStore()

const loading = ref(true)
const recentlyPlayed = ref<Track[]>([])
const recentlyAdded = ref<Track[]>([])
const recentAlbums = ref<AlbumCardData[]>([])
const favorites = ref<Track[]>([])
const playlists = ref<PlaylistCard[]>([])

onMounted(async () => {
  try {
    const { data } = await api.get('/home')
    recentlyPlayed.value = data.recently_played
    recentlyAdded.value = data.recently_added
    recentAlbums.value = data.recent_albums
    favorites.value = data.favorites
    playlists.value = data.playlists
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="p-8 pb-32 max-w-6xl mx-auto text-app">
    <header class="mb-10">
      <h1 class="text-4xl font-semibold tracking-tight">
        {{ $t('app.welcome', { name: auth.user?.username ?? $t('app.friend') }) }}
      </h1>
      <p class="text-muted mt-1">{{ $t('app.libraryReady') }}</p>
    </header>

    <!-- Skeleton -->
    <div v-if="loading" class="space-y-10">
      <div v-for="i in 3" :key="i" class="space-y-4">
        <Skeleton variant="text" width="12rem" height="1.5rem" />
        <div class="flex gap-4 overflow-hidden">
          <Skeleton v-for="j in 6" :key="j" variant="block" width="10rem" height="10rem" />
        </div>
      </div>
    </div>

    <template v-else>
      <!-- Recently played -->
      <section v-if="recentlyPlayed.length" class="mb-10">
        <SectionHeader :title="$t('home.recentlyPlayed')" />
        <div class="flex gap-4 overflow-x-auto scroll-slim pb-2">
          <TrackCard
            v-for="t in recentlyPlayed"
            :key="t.id"
            :track="t"
            :queue="recentlyPlayed"
          />
        </div>
      </section>

      <!-- Recently added -->
      <section v-if="recentlyAdded.length" class="mb-10">
        <SectionHeader :title="$t('home.recentlyAdded')" />
        <div class="flex gap-4 overflow-x-auto scroll-slim pb-2">
          <TrackCard
            v-for="t in recentlyAdded"
            :key="t.id"
            :track="t"
            :queue="recentlyAdded"
          />
        </div>
      </section>

      <!-- New albums -->
      <section v-if="recentAlbums.length" class="mb-10">
        <SectionHeader
          :title="$t('home.newAlbums')"
          :more-label="$t('nav.albums')"
          more-to="/albums"
        />
        <div class="flex gap-4 overflow-x-auto scroll-slim pb-2">
          <AlbumCard v-for="a in recentAlbums" :key="a.id" :album="a" />
        </div>
      </section>

      <!-- Favorites -->
      <section v-if="favorites.length" class="mb-10">
        <SectionHeader
          :title="$t('home.yourFavorites')"
          :more-label="$t('nav.favorites')"
          more-to="/favorites"
        />
        <div class="flex gap-4 overflow-x-auto scroll-slim pb-2">
          <TrackCard
            v-for="t in favorites"
            :key="t.id"
            :track="t"
            :queue="favorites"
          />
        </div>
      </section>

      <!-- Playlists -->
      <section v-if="playlists.length" class="mb-10">
        <SectionHeader
          :title="$t('home.yourPlaylists')"
          :more-label="$t('nav.playlists')"
          more-to="/playlists"
        />
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <RouterLink
            v-for="p in playlists"
            :key="p.id"
            :to="`/playlists/${p.id}`"
            class="block bg-surface rounded-xl border border-app p-5
                   hover:shadow-xl hover:-translate-y-0.5 transition-all"
          >
            <div class="text-lg font-medium truncate">{{ p.name }}</div>
            <div class="text-sm text-muted mt-1">
              {{ $t('playlists.trackCount', { n: p.track_count }) }}
            </div>
          </RouterLink>
        </div>
      </section>

      <!-- Empty library -->
      <section v-if="!recentlyPlayed.length && !recentlyAdded.length" class="text-center py-16">
        <h2 class="text-xl font-semibold text-app mb-2">{{ $t('home.emptyTitle') }}</h2>
        <p class="text-muted">{{ $t('home.emptyDescription') }}</p>
      </section>
    </template>
  </div>
</template>
