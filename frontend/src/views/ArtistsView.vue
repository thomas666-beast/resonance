<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import api from '@/api/client'

interface Artist { id: number; name: string; sort_name: string | null }

const artists = ref<Artist[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    const { data } = await api.get('/artists')
    artists.value = data.artists
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Failed to load artists'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="p-8">
    <h1 class="text-2xl font-bold mb-6">Artists</h1>
    <p v-if="loading" class="text-gray-500">Loading…</p>
    <p v-else-if="error" class="text-red-600">{{ error }}</p>
    <p v-else-if="artists.length === 0" class="text-gray-500">
      No artists yet. Trigger a scan from the backend.
    </p>
    <ul v-else class="space-y-2">
      <li v-for="a in artists" :key="a.id">
        <RouterLink :to="`/artists/${a.id}`" class="hover:underline">{{ a.name }}</RouterLink>
      </li>
    </ul>
  </div>
</template>
