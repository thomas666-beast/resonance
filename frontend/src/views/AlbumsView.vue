<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import api from '@/api/client'
import { useI18n } from 'vue-i18n'
import AlbumCover from '@/components/AlbumCover.vue'
import SkeletonGrid from '@/components/SkeletonGrid.vue'
import EmptyState from '@/components/EmptyState.vue'

const { t } = useI18n()

interface Album {
  id: number
  title: string
  year: number | null
  cover_path: string | null
  artist_id: number | null
  artist_name: string | null
  track_count: number
}

const albums  = ref<Album[]>([])
const loading = ref(true)
const error   = ref<string | null>(null)

onMounted(async () => {
  try {
    const { data } = await api.get('/albums', { params: { limit: 200 } })
    albums.value = data.albums
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Failed to load albums'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="p-4 md:p-8 pb-32 max-w-6xl mx-auto text-app">
    <h1 class="text-title mb-8">{{ $t('albums.title') }}</h1>

    <p v-if="error" class="text-danger">{{ error }}</p>

    <SkeletonGrid v-else-if="loading" :count="12" />

    <EmptyState
      v-else-if="!albums.length"
      icon="album"
      :title="$t('albums.emptyTitle')"
      :description="$t('albums.emptyDescription')"
    />

    <div v-else class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3 md:gap-4">
      <RouterLink
        v-for="(a, i) in albums"
        :key="a.id"
        :to="`/albums/${a.id}`"
        class="group block anim-fade-slide"
        :style="{ animationDelay: Math.min(i, 12) * 30 + 'ms' }"
      >
        <div class="aspect-square rounded-xl overflow-hidden shadow-lg
                    group-hover:shadow-xl group-hover:-translate-y-0.5
                    transition-all duration-200">
          <AlbumCover :album-id="a.id" fill />
        </div>
        <div class="mt-3">
          <div class="text-sm font-medium truncate text-app">{{ a.title }}</div>
          <div class="text-xs text-muted truncate">
            <template v-if="a.artist_name">{{ a.artist_name }}</template>
            <template v-if="a.artist_name && a.year"> · </template>
            <template v-if="a.year">{{ a.year }}</template>
          </div>
        </div>
      </RouterLink>
    </div>
  </div>
</template>
