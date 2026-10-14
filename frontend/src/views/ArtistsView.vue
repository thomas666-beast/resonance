<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import api from '@/api/client'
import { useI18n } from 'vue-i18n'
import { useScanStore } from '@/stores/scan'

const { t } = useI18n()
const scan = useScanStore()

interface Artist { id: number; name: string; sort_name: string | null }
const artists = ref<Artist[]>([])
const loading = ref(true)
const error = ref<string | null>(null)

async function load() {
  try {
    const { data } = await api.get('/artists')
    artists.value = data.artists
  } catch (e: any) {
    error.value = e.response?.data?.error ?? t('artists.loadFailed')
  } finally {
    loading.value = false
  }
}

onMounted(load)

// When a scan finishes, reload
watch(() => scan.lastResult, (r) => {
  if (r) load()
})
</script>

<template>
  <div class="p-8">
    <h1 class="text-2xl font-bold mb-6">{{ $t('artists.title') }}</h1>
    <p v-if="loading" class="text-gray-500">{{ $t('artists.loading') }}</p>
    <p v-else-if="error" class="text-red-600">{{ error }}</p>
    <p v-else-if="artists.length === 0" class="text-gray-500">{{ $t('artists.empty') }}</p>
    <ul v-else class="space-y-2">
      <li v-for="a in artists" :key="a.id">
        <RouterLink :to="`/artists/${a.id}`" class="hover:underline">{{ a.name }}</RouterLink>
      </li>
    </ul>
  </div>
</template>
