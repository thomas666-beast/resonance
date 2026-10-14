<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import api from '@/api/client'
import { useI18n } from 'vue-i18n'
import { useScanStore } from '@/stores/scan'
import SkeletonList from '@/components/SkeletonList.vue'
import EmptyState from '@/components/EmptyState.vue'

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
    <h1 class="text-title mb-6">{{ $t('artists.title') }}</h1>

    <p v-if="error" class="text-danger">{{ error }}</p>

    <SkeletonList v-else-if="loading" :count="10" />

    <EmptyState
      v-else-if="!artists.length"
      icon="artist"
      :title="$t('artists.emptyTitle')"
      :description="$t('artists.emptyDescription')"
      :action-label="$t('scan.start')"
      action-to="/"
    />

    <ul v-else class="space-y-1">
      <li
        v-for="(a, i) in artists"
        :key="a.id"
        class="anim-fade-slide"
        :style="{ animationDelay: Math.min(i, 12) * 30 + 'ms' }"
      >
        <RouterLink :to="`/artists/${a.id}`"
                    class="block px-3 py-2 rounded-lg hover-surface transition-colors">
          {{ a.name }}
        </RouterLink>
      </li>
    </ul>
  </div>
</template>
