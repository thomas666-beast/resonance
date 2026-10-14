<script setup lang="ts">
import { onMounted, ref } from 'vue'
import api from '@/api/client'
import { useI18n } from 'vue-i18n'
import { useFavoritesStore } from '@/stores/favorites'
import { type Track } from '@/stores/player'
import TrackRow from '@/components/TrackRow.vue'

const { t } = useI18n()
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
  <div class="p-8 pb-32 max-w-4xl mx-auto">
    <h1 class="text-3xl font-semibold tracking-tight mb-8">{{ $t('favorites.title') }}</h1>

    <p v-if="loading" class="text-stone-500">{{ $t('common.loading') }}</p>
    <p v-else-if="!tracks.length" class="text-stone-500">{{ $t('favorites.empty') }}</p>

    <div v-else class="space-y-0.5">
      <TrackRow
        v-for="t in tracks"
        :key="t.id"
        :track="t"
        :queue="tracks"
        show-artist
        show-album
      />
    </div>
  </div>
</template>
