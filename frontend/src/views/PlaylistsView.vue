<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { usePlaylistsStore } from '@/stores/playlists'

const { t } = useI18n()
const router = useRouter()
const playlists = usePlaylistsStore()
const creating = ref(false)

onMounted(() => playlists.load())

async function createNew() {
  const name = prompt(t('playlists.newNamePrompt'))
  if (!name) return
  creating.value = true
  try {
    const pl = await playlists.create(name)
    router.push(`/playlists/${pl.id}`)
  } finally {
    creating.value = false
  }
}
</script>

<template>
  <div class="p-8 pb-32 max-w-5xl mx-auto text-app">
    <header class="flex items-center justify-between mb-8">
      <h1 class="text-3xl font-semibold tracking-tight">{{ $t('playlists.title') }}</h1>
      <button
        @click="createNew"
        :disabled="creating"
        class="px-4 py-2 bg-accent text-white rounded-full text-sm font-medium
               hover:opacity-90 disabled:opacity-40 transition-opacity"
      >
        + {{ $t('playlists.newPlaylist') }}
      </button>
    </header>

    <p v-if="!playlists.items.length" class="text-muted">
      {{ $t('playlists.empty') }}
    </p>

    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <RouterLink
        v-for="p in playlists.items"
        :key="p.id"
        :to="`/playlists/${p.id}`"
        class="block bg-surface rounded-xl border border-app p-5
               hover:shadow-xl hover:-translate-y-0.5 transition-all"
      >
        <div class="text-lg font-medium truncate">{{ p.name }}</div>
        <div class="text-sm text-muted mt-1">
          {{ $t('playlists.trackCount', { n: p.track_count }) }}
        </div>
        <div v-if="p.is_public"
             class="text-xs text-accent mt-2 inline-block px-2 py-0.5 bg-surface-2 rounded-full border border-app">
          {{ $t('playlists.public') }}
        </div>
      </RouterLink>
    </div>
  </div>
</template>
