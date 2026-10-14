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

watch(() => scan.lastResult, (r) => { if (r) load() })
</script>

<template>
  <div class="p-8 pb-32 max-w-4xl mx-auto text-app">
    <h1 class="text-2xl font-bold mb-6">{{ $t('artists.title') }}</h1>
    <p v-if="loading" class="text-muted">{{ $t('artists.loading') }}</p>
    <p v-else-if="error" class="text-danger">{{ error }}</p>
    <p v-else-if="artists.length === 0" class="text-muted">{{ $t('artists.empty') }}</p>
    <ul v-else class="space-y-1">
      <li v-for="a in artists" :key="a.id">
        <RouterLink :to="`/artists/${a.id}`"
                    class="block px-3 py-2 rounded-lg hover-surface transition-colors">
          {{ a.name }}
        </RouterLink>
      </li>
    </ul>
  </div>
</template>
