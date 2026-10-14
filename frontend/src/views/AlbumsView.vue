<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import api from '@/api/client'
import { useI18n } from 'vue-i18n'

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
  <div class="p-8 pb-32 max-w-6xl mx-auto">
    <h1 class="text-3xl font-semibold tracking-tight mb-8">{{ $t('albums.title') }}</h1>

    <p v-if="loading" class="text-stone-500">{{ $t('common.loading') }}</p>
    <p v-else-if="error" class="text-red-600">{{ error }}</p>
    <p v-else-if="!albums.length" class="text-stone-500">{{ $t('albums.empty') }}</p>

    <div v-else class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
      <RouterLink
        v-for="a in albums"
        :key="a.id"
        :to="`/albums/${a.id}`"
        class="group block"
      >
        <div class="aspect-square bg-stone-100 rounded-xl overflow-hidden
                    shadow-sm group-hover:shadow-md group-hover:-translate-y-0.5
                    transition-all flex items-center justify-center">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
               class="w-12 h-12 stroke-stone-300 fill-none" stroke-width="1.5">
            <circle cx="12" cy="12" r="9" />
            <circle cx="12" cy="12" r="2" />
          </svg>
        </div>
        <div class="mt-3">
          <div class="text-sm font-medium truncate">{{ a.title }}</div>
          <div class="text-xs text-stone-500 truncate">
            <template v-if="a.artist_name">{{ a.artist_name }}</template>
            <template v-if="a.artist_name && a.year"> · </template>
            <template v-if="a.year">{{ a.year }}</template>
          </div>
        </div>
      </RouterLink>
    </div>
  </div>
</template>
