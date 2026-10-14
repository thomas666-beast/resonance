<script setup lang="ts">
import { onMounted, ref } from 'vue'
import api from '@/api/client'
import { useFavoritesStore } from '@/stores/favorites'
import { type Track } from '@/stores/player'
import TrackRow from '@/components/TrackRow.vue'
import SkeletonList from '@/components/SkeletonList.vue'
import EmptyState from '@/components/EmptyState.vue'

const favorites = useFavoritesStore()

const tracks = ref<Track[]>([])
const loading = ref(true)

async function load() {
  loading.value = true
  try {
    const { data } = await api.get('/favorites')
    tracks.value = data.tracks
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="p-8 pb-32 max-w-4xl mx-auto text-app">
    <h1 class="text-title mb-8">{{ $t('favorites.title') }}</h1>

    <SkeletonList v-if="loading" :count="8" />

    <EmptyState
      v-else-if="!tracks.length"
      icon="heart"
      :title="$t('favorites.emptyTitle')"
      :description="$t('favorites.emptyDescription')"
      :action-label="$t('nav.albums')"
      action-to="/albums"
    />

    <div v-else class="space-y-0.5">
      <div
        v-for="(t, i) in tracks"
        :key="t.id"
        class="anim-fade-slide"
        :style="{ animationDelay: Math.min(i, 12) * 25 + 'ms' }"
      >
        <TrackRow
          :track="t"
          :queue="tracks"
          show-artist
          show-album
        />
      </div>
    </div>
  </div>
</template>
