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
  <div class="p-8 pb-32">
    <p v-if="loading">Loading…</p>
    <p v-else-if="error" class="text-red-600">{{ error }}</p>
    <template v-else-if="artist">
      <h1 class="text-3xl font-bold mb-6">{{ artist.name }}</h1>
      <h2 class="text-lg font-semibold mb-3">Albums</h2>
      <ul class="space-y-2">
        <li v-for="a in albums" :key="a.id">
          <RouterLink :to="`/albums/${a.id}`" class="hover:underline">
            {{ a.title }} <span v-if="a.year" class="text-gray-500">({{ a.year }})</span>
          </RouterLink>
        </li>
      </ul>
    </template>
  </div>
</template>
