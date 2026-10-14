<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import api from '@/api/client'

const route = useRoute()

const artist = ref<any>(null)
const albums = ref<any[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    const { data } = await api.get(`/artists/${route.params.id}`)
    artist.value = data.artist
    albums.value = data.albums
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Failed to load artist'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="p-8 pb-32 max-w-4xl mx-auto text-app">
    <p v-if="loading" class="text-muted">{{ $t('common.loading') }}</p>
    <p v-else-if="error" class="text-danger">{{ error }}</p>
    <template v-else-if="artist">
      <p class="text-label mb-2">{{ $t('artists.title') }}</p>
      <h1 class="text-display mb-10">{{ artist.name }}</h1>

      <h2 class="text-heading mb-4 text-muted">{{ $t('albums.title') }}</h2>
      <ul class="space-y-1">
        <li v-for="a in albums" :key="a.id">
          <RouterLink :to="`/albums/${a.id}`"
                      class="block px-3 py-2 rounded-lg hover-surface transition-colors">
            {{ a.title }} <span v-if="a.year" class="text-muted">({{ a.year }})</span>
          </RouterLink>
        </li>
      </ul>
    </template>
  </div>
</template>
